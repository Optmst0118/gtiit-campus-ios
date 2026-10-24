import SwiftUI
import UIKit

/// 独立测试包：用原 App 的完整 RootTabView 检查外观及 Dynamic Type，不进入产品 target。
@main struct UIReviewApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var app: AppModel
    @StateObject private var previewLock: AppLockController
    private let environment = ProcessInfo.processInfo.environment
    init() {
        Theme.configureNavigationAppearance()
        let defaults = UserDefaults(suiteName: "ui-review.preferences")!
        defaults.removePersistentDomain(forName: "ui-review.preferences")
        if let grid = ProcessInfo.processInfo.environment["UI_REVIEW_DOWNLOAD_GRID"] {
            UserDefaults.standard.set(grid == "1", forKey: "downloads.grid")
        }
        let settings = AppSettings(defaults: defaults)
        settings.hasSeenWelcome = true
        settings.language = ProcessInfo.processInfo.environment["UI_REVIEW_ENGLISH"] == "1" ? .english : .chinese
        settings.preloadSitesOnLaunch = false
        settings.startupTab = ProcessInfo.processInfo.environment["UI_REVIEW_SHUTTLE"] == "1" ? .shuttle : .me
        settings.appearance = ProcessInfo.processInfo.environment["UI_REVIEW_DARK"] == "1" ? .dark : .light
        _settings = StateObject(wrappedValue: settings)
        let model = AppModel(settings: settings)
        if ProcessInfo.processInfo.environment["UI_REVIEW_TIMETABLE"] == "1" {
            let classes = (1...5).flatMap { day in [
                LocalCourse(name: "Engineering Mechanics", code: "TEST1001", group: "L10", weekday: day, start: "08:00", end: "09:45", room: "SC E1-201", building: "Education Building 1"),
                LocalCourse(name: "Design Studio", code: "TEST2002", group: "Lab20", weekday: day, start: "14:00", end: "16:00", room: "SC E2-302", building: "Education Building 2")
            ] }
            try? model.timetable.save(TimetableSnapshot(semester: "Synthetic review semester", validFrom: "2026-10-12", validUntil: "2027-01-11", courses: classes))
        }
        if ProcessInfo.processInfo.environment["UI_REVIEW_EMPTY_TIMETABLE"] == "1" { try? model.timetable.clear() }
        if ProcessInfo.processInfo.environment["UI_REVIEW_MOODLE"] == "1" {
            model.browser(for: .moodle).webView.loadHTMLString(#"""
            <html><title>Synthetic Moodle</title><script>
            window.M={cfg:{wwwroot:'https://moodle.gtiit.edu.cn/moodle',sesskey:'SYNTHETIC_ONLY'}};
            window.fetch=async(url,options={})=>{
              const u=new URL(url);let body='';
              if(u.pathname.endsWith('service.php')){
                const q=JSON.parse(options.body)[0];body=JSON.stringify([{error:false,data:q.methodname.includes('enrolled_courses')?{courses:[{id:1,fullname:'Introduction to Robotics'}],nextoffset:0}:{events:[]}}]);
              }else if(u.pathname.endsWith('index.php'))body='<a href="https://moodle.gtiit.edu.cn/moodle/mod/assign/view.php?id=1">Homework 2</a>';
              else body='<div class="submissionstatustable"><table><tr><td>Submission status</td><td>No attempt</td></tr><tr><td>Due date</td><td>Sunday, 25 October 2026, 11:59 PM</td></tr></table></div>';
              return {ok:true,url:u.href,text:async()=>body};
            };
            </script></html>
            """#, baseURL: URL(string: "https://moodle.gtiit.edu.cn/moodle/my/")!)
        }
        if let raw = ProcessInfo.processInfo.environment["UI_REVIEW_SITE"], let site = SiteID(rawValue: raw) { model.openSite(site) }
        if ProcessInfo.processInfo.environment["UI_REVIEW_WEB_FIXTURE"] == "1" {
            let site = SiteID(rawValue: ProcessInfo.processInfo.environment["UI_REVIEW_SITE"] ?? "portal") ?? .portal
            model.openSite(site)
            let rows = (1...28).map { "<div class='row'>Campus item \($0)<span>Course · Room · 09:00</span></div>" }.joined()
            model.browser(for: site).webView.loadHTMLString("""
                <html><head><title>Campus content</title><meta name="viewport" content="width=device-width, initial-scale=1"><style>
                html,body{height:100%}body{margin:0;background:white;color:#161e28;font:17px -apple-system}#root{height:100%;overflow:hidden}main{height:100%;overflow-y:auto;box-sizing:border-box}h1{padding:20px 20px 0;font-size:30px}.row{padding:20px;border-bottom:1px solid #ddd;background:#eef7ff}.row:nth-child(2n){background:#d5eaff}.row span{display:block;font-size:13px;padding-top:6px}#tail{margin:20px;padding:16px;border:0;border-radius:12px;background:#0675bc;color:white}
                </style></head><body><div id="root"><main><h1>Campus content</h1>\(rows)<button id="tail">Last page action</button></main></div></body></html>
                """, baseURL: site.homeURL)
        }
        if ProcessInfo.processInfo.environment["UI_REVIEW_EXAMS"] == "1" {
            try? model.exams.accept(semester: "Synthetic semester", items: [StudentExam(course: "Engineering Mathematics", code: "TEST1001", session: "Mid", date: "2026-11-21", time: "09:00", duration: 2, venue: "SC E1-201")])
        }
        if ProcessInfo.processInfo.environment["UI_REVIEW_WELCOME_FIXTURE"] == "1" {
            for site in SiteID.allCases {
                let browser = model.browser(for: site)
                browser.webView.stopLoading()
                browser.webView.loadHTMLString("<html><head><meta name='viewport' content='width=device-width, initial-scale=1'></head><body style='font:18px -apple-system;padding:24px'><h1>\(site.displayName)</h1><p>Synthetic signed-in page</p></body></html>", baseURL: site.homeURL)
            }
        }
        _app = StateObject(wrappedValue: model)
        let lock = AppLockController(authenticator: PreviewUnavailableAuthenticator())
        lock.lock()
        _previewLock = StateObject(wrappedValue: lock)
    }
    var body: some Scene {
        WindowGroup {
            Group {
                if environment["UI_REVIEW_WELCOME"] == "1" {
                    WelcomeView().environmentObject(app).environmentObject(settings)
                } else if environment["UI_REVIEW_ACTIVITY"] == "1" {
                    VStack(spacing: 24) {
                        ForEach(ShuttleDirection.allCases) { direction in
                            ShuttleActivitySummary(attributes: ShuttleActivityAttributes(directionTitle: direction.title,
                                origin: direction.origin, destination: direction.destination, departureTime: "17:25",
                                busLabel: L10n.format("%@ 号车", "1"), directionRaw: direction.rawValue,
                                languageCode: settings.language.rawValue, departedLabel: L10n.tr("计划时间已过")),
                                state: .init(departureDate: Date().addingTimeInterval(345), busNumber: 1))
                                .background(Color(red: 0.055, green: 0.078, blue: 0.11), in: RoundedRectangle(cornerRadius: 24))
                        }
                    }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity).background(Theme.pageBackground)
                } else if environment["UI_REVIEW_SHORTCUTS"] == "1" {
                    NavigationStack {
                        ScrollView {
                            CampusShortcutsSection().padding(.horizontal, 20).padding(.bottom, 20)
                        }
                        .background(Theme.pageBackground)
                        .navigationTitle(L10n.tr("我的"))
                        .navigationBarTitleDisplayMode(.inline)
                    }.environmentObject(app).environmentObject(settings)
                } else if environment["UI_REVIEW_TIMETABLE_SETTINGS"] == "1" {
                    NavigationStack { TimetableSettingsView() }.environmentObject(app).environmentObject(settings)
                } else if environment["UI_REVIEW_SHORTCUT_SETTINGS"] == "1" {
                    NavigationStack { ShortcutSettingsView() }.environmentObject(app).environmentObject(settings)
                } else if environment["UI_REVIEW_IMPORT"] == "1" {
                    TimetableImportView(initialDraft: app.timetable.snapshot).environmentObject(app).environmentObject(settings)
                } else if environment["UI_REVIEW_IMPORT_START"] == "1" {
                    TimetableImportView().environmentObject(app).environmentObject(settings)
                } else if environment["UI_REVIEW_ERROR"] == "1" {
                    LoadErrorView(site: .portal, message: L10n.tr("连接超时。校园站点在校外可能需要较长时间，请稍后重试。"), onRetry: {}, onOpenSafari: {}, onOpenHome: {})
                } else if environment["UI_REVIEW_CALENDAR"] == "1" {
                    NavigationStack { AcademicCalendarView() }
                } else if environment["UI_REVIEW_WEEK"] == "1" {
                    NavigationStack { LocalTimetableView(store: app.timetable).environmentObject(app) }
                } else if environment["UI_REVIEW_ABOUT"] == "1" {
                    NavigationStack { AboutView().environmentObject(app).environmentObject(settings) }
                        .overlay { YilongOverlay(controller: app.yilong) }
                } else if environment["UI_REVIEW_DOWNLOADS"] == "1" {
                    NavigationStack { DownloadsView(center: app.downloads).environmentObject(app).environmentObject(settings) }
                        .task {
                            if app.downloads.items.isEmpty {
                                let source = FileManager.default.temporaryDirectory.appendingPathComponent("review.pdf")
                                let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
                                let data = renderer.pdfData { context in
                                    context.beginPage()
                                    ("GTIIT PDF Preview\nVisual test fixture\n\nPinch to zoom. Scroll to read." as NSString).draw(at: CGPoint(x: 48, y: 80), withAttributes: [.font: UIFont.systemFont(ofSize: 24)])
                                }
                                try? data.write(to: source)
                                for name in ["Robotics syllabus.pdf", "Engineering mathematics.pdf", "Campus reference.pdf", "Week 3 notes.pdf"] {
                                    _ = try? await app.downloads.savePreview(source, filename: name, site: .moodle)
                                }
                            }
                            if environment["UI_REVIEW_DISTINCT_DOWNLOADS"] == "1" {
                                for item in app.downloads.items { await app.downloads.removeFile(item.id) }
                                for name in ["North Campus Schedule.pdf", "South Campus Schedule.pdf"] {
                                    let source = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                                    let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 595, height: 842))
                                    let data = renderer.pdfData { context in
                                        context.beginPage()
                                        (name + "\n\nIndependent file preview\nSynthetic verification document" as NSString).draw(at: CGPoint(x: 40, y: 70), withAttributes: [.font: UIFont.systemFont(ofSize: 25)])
                                    }
                                    try? data.write(to: source)
                                    _ = try? await app.downloads.savePreview(source, filename: name, site: .moodle)
                                }
                            }
                            if environment["UI_REVIEW_PDF"] == "1", let item = app.downloads.items.first { app.downloads.open(item) }
                            if environment["UI_REVIEW_UNSAVED_PDF"] == "1", let item = app.downloads.items.first, let url = app.downloads.fileURL(for: item) {
                                let session = PDFPreviewSession(site: .moodle)
                                session.filename = "PDF Preview.pdf"; session.read(url)
                                let controller = UIHostingController(rootView: DocumentPreviewView(session: session))
                                controller.modalPresentationStyle = .fullScreen
                                session.closeAction = { [weak controller] in controller?.dismiss(animated: true) }
                                session.saveAction = {
                                    guard session.canSave else { return }; session.state = .saving
                                    Task {
                                        do { let saved = try await app.downloads.savePreview(url, filename: session.filename, site: .moodle); session.savedURL = app.downloads.fileURL(for: saved); session.state = .saved }
                                        catch { session.state = .readable; session.error = error.localizedDescription }
                                    }
                                }
                                _ = app.browserPresent(viewController: controller)
                            }
                        }
                } else if environment["UI_REVIEW_LOCK"] == "1" {
                    LockScreenView().environmentObject(previewLock)
                } else {
                    RootTabView().environmentObject(app).environmentObject(settings)
                }
            }
            .modifier(ContextMenuBackdrop(active: app.contextMenuSource != nil && (environment["UI_REVIEW_SHORTCUTS"] == "1" || environment["UI_REVIEW_DOWNLOADS"] == "1")))
            .environment(\.locale, Locale(identifier: settings.language.rawValue))
            .tint(Theme.accent)
            .preferredColorScheme(settings.appearance.colorScheme)
            .background(
                SceneWindowReader { scene in
                    scene.traitOverrides.preferredContentSizeCategory =
                        environment["UI_REVIEW_LARGE_TEXT"] == "1"
                        ? .accessibilityExtraExtraExtraLarge : .large
                }.frame(width: 0, height: 0))
        }
    }
}

@MainActor private final class PreviewUnavailableAuthenticator: LocalAuthenticating {
    var isAvailable: Bool { false }
    var label: String { "设备密码" }
    func authenticate() async throws -> Bool { false }
}
