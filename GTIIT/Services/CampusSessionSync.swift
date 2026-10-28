import SwiftUI
import WebKit

/// One sequential, read-only browser, using each site's existing persistent
/// session. Never navigates or edits a visible tab. Login state isn't inferred
/// from the presence of cookies or a successful HTTP response.
@MainActor final class CampusSessionSync: NSObject, ObservableObject, WKNavigationDelegate {
    @Published private(set) var states: [SiteID: CampusLoginState] = [:]
    @Published private(set) var probe: WKWebView?
    @Published private(set) var checking = false
    @Published private(set) var studentCourses: [CachedCampusCourse] = []
    @Published private(set) var reservations: [CachedRoomReservation] = []
    @Published private(set) var coursesUpdatedAt: Date?
    @Published private(set) var reservationsUpdatedAt: Date?
    private var hasStarted = false
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var revisions: [SiteID: Int] = [:]
    private var networkFailed = false
    private var lastRoomAttempt: Date?
    private var pendingRoomRefresh = false
    private let cacheURL: URL
    private struct Cache: Codable {
        let version: Int
        let courses: [CachedCampusCourse]
        let reservations: [CachedRoomReservation]
        let coursesUpdatedAt: Date?
        let reservationsUpdatedAt: Date?
    }
    init(directory: URL? = nil) {
        cacheURL = (directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CampusLocalCache")).appendingPathComponent("cache.json")
        super.init()
        if let cache = ProtectedCampusCache.read(Cache.self, from: cacheURL, maxBytes: 5_000_000), cache.version == 1 {
            studentCourses = cache.courses.filter { !$0.name.isEmpty && $0.name.count <= 1000 }
            reservations = cache.reservations.filter(\.valid)
            coursesUpdatedAt = cache.coursesUpdatedAt; reservationsUpdatedAt = cache.reservationsUpdatedAt
        }
    }
    func start(force: Bool = false, sites: [SiteID] = SiteID.allCases, allowed: @escaping @MainActor () -> Bool) {
        guard !checking, allowed(), force || !hasStarted else { return }
        if sites == SiteID.allCases { hasStarted = true }; checking = true
        for site in sites { states[site] = .checking }
        let token = UUID(); generation = token
        task = Task { [weak self] in
            guard let self else { return }
            defer {
                if generation == token {
                    probe?.stopLoading(); probe?.navigationDelegate = nil; probe = nil; checking = false; task = nil
                    if pendingRoomRefresh && allowed() {
                        pendingRoomRefresh = false
                        Task { @MainActor [weak self] in self?.start(force: true, sites: [.rooms], allowed: allowed) }
                    }
                }
            }
            for site in sites {
                guard !Task.isCancelled, generation == token, allowed() else { return }
                if site == .rooms { lastRoomAttempt = Date() }
                let revision = revisions[site, default: 0]
                states[site] = .checking
                let config = WKWebViewConfiguration()
                config.websiteDataStore = WebDataStoreRegistry.shared.store(for: site)
                let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
                web.navigationDelegate = self; probe = web
                let target: URL
                if site == .rooms { target = BookingDirectory.roomsMyCalendarURL }
                else if site == .sports { target = URL(string: "https://gtiit.mike-x.com/kcr2S")! }
                else { target = site.homeURL }
                networkFailed = false; web.load(URLRequest(url: target))
                let state = await check(web, site: site, token: token, allowed: allowed)
                guard !Task.isCancelled, generation == token, allowed() else { return }
                if revisions[site, default: 0] == revision { states[site] = state }
                if state == .signedIn {
                    if site == .rooms { await readReservations(web, token: token) }
                    if site == .portal {
                        await readCourses(web, token: token)
                        // Academic history and registered schedule are read in
                        // this dedicated browser; the user's portal stays put.
                        for path in ["grades", "enrollments"] {
                            guard allowed(), generation == token, !Task.isCancelled else { return }
                            web.load(URLRequest(url: site.homeURL.appendingPathComponent(path)))
                            _ = await check(web, site: site, token: token, allowed: allowed)
                            await readCourses(web, token: token)
                        }
                    }
                }
                web.stopLoading(); web.navigationDelegate = nil; probe = nil
            }
        }
    }
    func refreshRooms(force: Bool = false, allowed: @escaping @MainActor () -> Bool) {
        guard allowed(), force || lastRoomAttempt.map({ Date().timeIntervalSince($0) >= 300 }) != false else { return }
        if checking { pendingRoomRefresh = true; return }
        start(force: true, sites: [.rooms], allowed: allowed)
    }
    func cancel() {
        generation = UUID(); task?.cancel(); task = nil; pendingRoomRefresh = false
        probe?.stopLoading(); probe?.navigationDelegate = nil; probe = nil; checking = false
        for site in states.keys where states[site] == .checking { states[site] = .unknown }
        // Interrupted checks resume after unlock, without repeating settled sites.
        hasStarted = false
    }
    func clear(_ site: SiteID? = nil) {
        cancel()
        if site == nil || site == .portal { studentCourses = []; coursesUpdatedAt = nil }
        if site == nil || site == .rooms { reservations = []; reservationsUpdatedAt = nil }
        if let site { states[site] = .needsLogin; revisions[site, default: 0] += 1 }
        else { states = [:]; revisions = [:] }
        persist()
    }
    func observe(_ web: WKWebView, site: SiteID) {
        revisions[site, default: 0] += 1
        let revision = revisions[site, default: 0]
        let token = generation
        Task { [weak self, weak web] in
            guard let self, let web, let state = await Self.state(in: web, site: site), revisions[site] == revision else { return }
            if state == .signedIn || state == .needsLogin { states[site] = state }
            if site == .portal, state == .signedIn { await readCourses(web, token: token) }
        }
    }
    private func check(_ web: WKWebView, site: SiteID, token: UUID, allowed: @escaping @MainActor () -> Bool) async -> CampusLoginState {
        var stableURL = ""; var stable = 0
        for _ in 0..<40 {
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return .unknown }
            guard generation == token, allowed(), !Task.isCancelled else { return .unknown }
            if networkFailed { return .unavailable }
            guard !web.isLoading, let url = web.url, url.scheme == "https" else { stable = 0; continue }
            if url.absoluteString == stableURL { stable += 1 } else { stableURL = url.absoluteString; stable = 0 }
            guard stable >= 2 else { continue }
            if let state = await Self.state(in: web, site: site), state != .unknown { return state }
        }
        return networkFailed ? .unavailable : .unknown
    }
    static func state(in web: WKWebView, site: SiteID) async -> CampusLoginState? {
        guard let url = web.url else { return nil }
        guard url.scheme == "https", url.host == site.host || NavigationPolicy.isAuthentication(url) else { return .unknown }
        let result = (try? await web.evaluateJavaScript(loginScript) as? String).flatMap(CampusLoginState.init(rawValue:))
        if url.host != site.host { return result == .needsLogin ? .needsLogin : .unknown }
        return result
    }
    static let loginScript = #"""
    (()=>{
      const visible=e=>!!e.getClientRects().length&&getComputedStyle(e).visibility!=='hidden';
      const path=location.pathname+location.hash;
      if(/(?:^|[\/#_-])(login|signin|sign-in|admin_password_auth)(?:[\/#?._-]|$)/i.test(path))return 'needsLogin';
      if(Array.from(document.querySelectorAll('input[type=password],input[autocomplete=one-time-code],#i0116')).some(visible))return 'needsLogin';
      const links=Array.from(document.querySelectorAll('a,button')).filter(visible);
      if(links.some(e=>/logout|logoff|sign.?out/i.test(e.getAttribute('href')||'')||/^(sign out|log out|退出登录|登出)$/i.test(e.textContent.trim())))return 'signedIn';
      if(location.hostname==='students.gtiit.edu.cn'&&document.querySelector('#Exams,.konvajs-content'))return 'signedIn';
      if(location.hostname==='moodle.gtiit.edu.cn'&&/guest|访客/i.test(document.querySelector('.usermenu .usertext')?.textContent||''))return 'needsLogin';
      if(location.hostname==='moodle.gtiit.edu.cn'&&document.querySelector('.usermenu .usertext,.usermenu .userbutton'))return 'signedIn';
      if(location.hostname==='servicehub.gtiit.edu.cn'&&document.querySelector('a[href="#current_user"]'))return 'signedIn';
      if(links.some(e=>/^(sign in|log in|login|登录|会员登录|microsoft)$/i.test(e.textContent.trim())))return 'needsLogin';
      return 'unknown';
    })()
    """#
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if !NavigationPolicy.isExpectedInterruption(error as NSError) { networkFailed = true } }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if !NavigationPolicy.isExpectedInterruption(error as NSError) { networkFailed = true } }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        decisionHandler(["https", "about"].contains(navigationAction.request.url?.scheme ?? "") ? .allow : .cancel)
    }
    private func persist() {
        do {
            try ProtectedCampusCache.write(Cache(version: 1, courses: studentCourses, reservations: reservations, coursesUpdatedAt: coursesUpdatedAt, reservationsUpdatedAt: reservationsUpdatedAt), to: cacheURL)
        } catch { /* Keep the prior atomic snapshot. The UI retains its last successful timestamp. */ }
    }
    func acceptCourses(_ courses: [CachedCampusCourse], at: Date = Date()) {
        var merged = Dictionary(studentCourses.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        for course in courses where !course.name.isEmpty && course.name.count <= 1000 && course.code.count <= 100 {
            merged[course.id] = course
        }
        studentCourses = merged.values.sorted { $0.semester == $1.semester ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : $0.semester > $1.semester }
        coursesUpdatedAt = at; persist()
    }
    func acceptReservations(_ items: [CachedRoomReservation], at: Date = Date()) {
        guard items.count <= 5000, items.allSatisfy(\.valid) else { return }
        reservations = Array(Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last }).values).sorted { $0.start < $1.start }
        reservationsUpdatedAt = at; persist()
    }
    private func readCourses(_ web: WKWebView, token: UUID) async {
        let entryURL = web.url
        // A signed-in shell can paint before its course query completes.
        // Wait for that component without exporting a premature empty snapshot.
        for _ in 0..<12 {
            guard generation == token, !Task.isCancelled, web.url == entryURL else { return }
            if let json = try? await web.evaluateJavaScript(Self.coursesScript) as? String,
               let data = json.data(using: .utf8), data.count < 2_000_000,
               let rows = try? JSONDecoder().decode([CachedCampusCourse].self, from: data), !rows.isEmpty {
                guard generation == token, web.url == entryURL else { return }
                acceptCourses(rows); return
            }
            do { try await Task.sleep(for: .milliseconds(500)) } catch { return }
        }
    }
    private func readReservations(_ web: WKWebView, token: UUID) async {
        do {
            let result = try await web.callAsyncJavaScript(Self.reservationsScript, arguments: [:], in: nil, contentWorld: .page)
            guard generation == token, !Task.isCancelled, let raw = result as? String, let data = raw.data(using: .utf8), data.count < 2_000_000 else { return }
            let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
            let rows = try decoder.decode([CachedRoomReservation].self, from: data)
            acceptReservations(rows)
        } catch { /* Incomplete/failed refresh cannot erase the previous personal calendar. */ }
    }
}

struct CampusSessionProbeHost: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

extension CampusSessionSync {
    static let coursesScript = #"""
    (()=>{
      if(location.hostname!=='students.gtiit.edu.cn')return null;
      const clean=v=>['string','number'].includes(typeof v)?String(v).trim().replace(/\s+/g,' ').slice(0,1000):'';
      const semester=Array.from(document.querySelectorAll('select')).map(s=>s.selectedOptions?.[0]?.textContent||'').find(s=>/20\d{2}.*(WINTER|SPRING|SUMMER)/i.test(s))||'';
      const out=new Map();
      const termLabels=new Map(Array.from(document.querySelectorAll('select option')).filter(o=>/(WINTER|SPRING|SUMMER)/i.test(o.textContent)).map(o=>[o.value,clean(o.textContent)]));
      const append=x=>{
        if(!x||typeof x!=='object'||!('courseName'in x)||!('courseCode'in x))return;
        if(x.enrolled===false||x.isPreview||x.postPending||x.deletePending)return;
        const c={code:clean(x.courseCode),name:clean(x.courseName),semester:clean(x.semesterName||x.semester||semester),teacher:clean(x.teacherName||x.instructorName),location:[clean(x.building),clean(x.classNumber)].filter(Boolean).join(' · '),credits:clean(x.credit)};
        if(c.name&&c.code)out.set(JSON.stringify(c),c);
      };
      // Inspect course component arrays only; never enumerate a global account store.
      for(const node of document.querySelectorAll('[id*=course i],#Exams,#Dashboard,.konvajs-content')){
        const host=node.classList.contains('konvajs-content')?node.parentElement:node;
        let f=host[Object.keys(host).find(k=>k.startsWith('__reactFiber$'))];
        for(let depth=0;f&&depth<16;depth++,f=f.return){
          const props=f.memoizedProps;
          for(const key of ['courses','groups','enrollments','records'])if(Array.isArray(props?.[key]))props[key].slice(0,5000).forEach(append);
          let hook=f.memoizedState;
          for(let n=0;hook&&n<40;n++,hook=hook.next){
            const memo=hook.memoizedState;
            // The portal's course query exposes {courses:{semester:[metadata]}}.
            // Accept only that schema; do not traverse other query/account fields.
            for(const value of [memo,Array.isArray(memo)?memo[0]:null,memo?.value]){
              const catalog=value?.data?.courses||value?.courses;
              if(!catalog||typeof catalog!=='object'||Array.isArray(catalog))continue;
              for(const [term,rows] of Object.entries(catalog)){
                if(!/^\d{4,8}$/.test(term)||!Array.isArray(rows)||!rows.every(x=>x&&'courseCode'in x&&'courseName'in x))continue;
                rows.slice(0,5000).forEach(x=>append({...x,semesterName:x.semesterName||termLabels.get(term)||term}));
              }
            }
            if(Array.isArray(memo)&&Array.isArray(memo[0])&&memo[0].every(x=>x&&typeof x==='object'&&'courseCode'in x&&'courseName'in x))memo[0].slice(0,5000).forEach(append);
          }
        }
      }
      for(const table of document.querySelectorAll('table')){
        const h=Array.from(table.querySelectorAll('thead th')).map(e=>clean(e.textContent).toLowerCase());
        const code=h.findIndex(s=>/course.*code|课程代码/.test(s)),name=h.findIndex(s=>/course.*name|course.*title|课程名称/.test(s));
        if(code<0||name<0)continue;
        const teacher=h.findIndex(s=>/instructor|teacher|教师/.test(s)),term=h.findIndex(s=>/semester|学期/.test(s));
        for(const row of table.querySelectorAll('tbody tr')){
          const c=Array.from(row.querySelectorAll('td')).map(e=>clean(e.textContent));
          if(c[code]&&c[name])append({courseCode:c[code],courseName:c[name],semesterName:c[term]||semester,teacherName:c[teacher]||''});
        }
      }
      return JSON.stringify(Array.from(out.values()));
    })()
    """#
    static let reservationsScript = #"""
    if(location.protocol!=='https:'||location.hostname!=='roombooking.gtiit.edu.cn'||location.pathname!=='/Web/my-calendar.php')throw Error('WRONG_PAGE');
    if(!document.querySelector('a[href*="logout.php"]'))throw Error('LOGIN_REQUIRED');
    const url=new URL('my-calendar.php',location.href);
    url.searchParams.set('dr','events');
    const day=n=>new Date(Date.now()+n*86400000+8*3600000).toISOString().slice(0,10);
    url.searchParams.set('start',day(-30));url.searchParams.set('end',day(365));
    const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),12000);
    try{
      const r=await fetch(url.href,{credentials:'same-origin',signal:controller.signal});
      if(!r.ok||new URL(r.url).origin!==location.origin||new URL(r.url).pathname!=='/Web/my-calendar.php')throw Error('UNAVAILABLE');
      const events=await r.json();if(!Array.isArray(events)||events.length>5000)throw Error('FORMAT_CHANGED');
      const clean=v=>String(v??'').replace(/<[^>]*>/g,' ').replace(/\s+/g,' ').trim().slice(0,1000);
      const timestamp=v=>{
        if(typeof v!=='string')return NaN;
        const raw=/Z$|[+-]\d{2}:?\d{2}$/.test(v)?v:v.replace(' ','T')+'+08:00';
        return Date.parse(raw)/1000;
      };
      const result=[];
      for(const e of events){
        const id=String(e.id??'');
        if(!id||!/^[-a-zA-Z0-9]{1,100}$/.test(id))throw Error('INVALID_REFERENCE');
        if(/cancel|deleted|rejected|declined/i.test([e.status,e.className].join(' ')))continue;
        const start=timestamp(e.start),end=timestamp(e.end),title=clean(e.title);
        if(!Number.isFinite(start)||!Number.isFinite(end)||end<=start||!title)throw Error('INVALID_EVENT');
        const place=title.match(/(?:SC\s*)?(?:[DE]\d[- ]\d{3}(?:[- ]\d+)?|E\d[- ]\d{3})/i)?.[0]||'';
        result.push({id,title,location:place,start,end,url:'https://roombooking.gtiit.edu.cn/Web/reservation.php?rn='+encodeURIComponent(id)});
      }
      return JSON.stringify(result);
    }finally{clearTimeout(timer);}
    """#
}
