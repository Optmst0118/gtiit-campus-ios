import SwiftUI

struct TodayTimetableCard: View {
    @Environment(\.locale) private var nativeLocale
    @ObservedObject var store: LocalTimetableStore
    var body: some View {
        let _ = nativeLocale.identifier

        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(L10n.tr("本地课表"), systemImage: "calendar").font(.headline)
                    Spacer()
                    Text(CampusDate.display(context.date, weekday: true)).font(.caption).foregroundStyle(.secondary)
                }
                if let snapshot = store.snapshot {
                    if let (course, date) = snapshot.next(after: context.date) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(L10n.tr("下一节")).font(.caption.weight(.semibold)).foregroundStyle(Theme.accent)
                            Text(course.name).font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                            Text("\(CampusDate.display(date, weekday: true)) · \(course.start)–\(course.end)")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(Theme.accent)
                            Label(course.location.isEmpty ? L10n.tr("教室待确认") : course.location, systemImage: "mappin.and.ellipse")
                                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    } else { Text(L10n.tr("暂无后续课程，请检查课表有效期。")).foregroundStyle(.secondary) }
                    Divider()
                    let courses = snapshot.courses(on: context.date)
                    if courses.isEmpty { Text(L10n.tr("今天没有课程")).font(.subheadline).foregroundStyle(.secondary) }
                    ForEach(courses) { course in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) { Text(course.start); Text(course.end).foregroundStyle(.secondary) }
                                .font(.caption.monospacedDigit()).frame(width: 45, alignment: .leading)
                            RoundedRectangle(cornerRadius: 2).fill(Theme.accent).frame(width: 3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(course.name).font(.subheadline.weight(.medium))
                                Text(course.location.isEmpty ? L10n.tr("教室待确认") : course.location).font(.caption).foregroundStyle(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text(L10n.tr("提取一次，离线查看每天课程与教室。")).font(.subheadline).foregroundStyle(.secondary)
                }
            }.padding(.vertical, 10)
        }
    }
}

struct LocalTimetableView: View {
    @Environment(\.locale) private var nativeLocale
    @ObservedObject var store: LocalTimetableStore
    @State private var anchor = Date()
    @State private var showImport = false
    @Environment(\.dynamicTypeSize) private var typeSize
    private var days: [Date] {
        let c = CampusDate.calendar
        let weekday = (c.component(.weekday, from: anchor) + 5) % 7
        let start = c.date(byAdding: .day, value: -weekday, to: c.startOfDay(for: anchor))!
        return (0..<7).compactMap { c.date(byAdding: .day, value: $0, to: start) }
    }
    var body: some View {
        let _ = nativeLocale.identifier

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                weekControls
                if let snapshot = store.snapshot {
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 12) { ForEach(days, id: \.self) { day in dayColumn(day, snapshot: snapshot) } }
                    } else {
                        ScrollViewReader { reader in
                            ScrollView(.horizontal) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(days, id: \.self) { day in dayColumn(day, snapshot: snapshot).frame(width: 210).id(CampusDate.key(day)) }
                                }.padding(.horizontal, 2)
                            }.scrollIndicators(.hidden)
                            .onAppear { reader.scrollTo(CampusDate.key(Date()), anchor: .leading) }
                            .onChange(of: anchor) { _, _ in
                                reader.scrollTo(days.contains(where: { CampusDate.calendar.isDateInToday($0) }) ? CampusDate.key(Date()) : CampusDate.key(days[0]), anchor: .leading)
                            }
                        }
                    }
                    Text("\(snapshot.semester) · \(snapshot.validFrom) – \(snapshot.validUntil)").font(.caption).foregroundStyle(.secondary)
                    Text(L10n.tr("离线快照；课程变动后需重新提取。已按已核实校历标注假期与调课，具体以学校通知为准。"))
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(L10n.format("上次提取：%@", CampusDate.display(snapshot.importedAt))).font(.caption).foregroundStyle(.secondary)
                } else {
                    ContentUnavailableView(L10n.tr("尚无本地课表"), systemImage: "calendar", description: Text(store.loadError ?? L10n.tr("从设置中提取门户课表后，即可离线查看。")))
                    Button(L10n.tr("提取课表")) { showImport = true }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                }
            }.padding(20)
        }.background(Theme.pageBackground).navigationTitle(L10n.tr("整周课表")).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.tr("更新"), systemImage: "arrow.clockwise") { showImport = true } } }
        .sheet(isPresented: $showImport) { NavigationStack { TimetableImportView().toolbar { ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("完成")) { showImport = false } } } } }
    }
    private var weekControls: some View {
        HStack {
            Button { shift(-7) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel(L10n.tr("上一周"))
            Spacer()
            VStack(spacing: 3) {
                Text(CampusDate.display(days[0])).font(.headline)
                Button(L10n.tr("回到本周")) { anchor = Date() }.font(.caption)
            }
            Spacer()
            Button { shift(7) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel(L10n.tr("下一周"))
        }
    }
    private func shift(_ value: Int) { anchor = CampusDate.calendar.date(byAdding: .day, value: value, to: anchor) ?? anchor }
    private func dayColumn(_ day: Date, snapshot: TimetableSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(CampusDate.display(day, weekday: true)).font(.headline).foregroundStyle(CampusDate.calendar.isDateInToday(day) ? Theme.accent : .primary)
            let courses = snapshot.courses(on: day)
            if courses.isEmpty { Text(L10n.tr("无课程")).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 20) }
            ForEach(courses) { course in
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(course.start) – \(course.end)").font(.subheadline.weight(.semibold).monospacedDigit()).foregroundStyle(Theme.accent)
                    Text(course.name).font(.headline).fixedSize(horizontal: false, vertical: true)
                    Text([course.code, course.group].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course.room.isEmpty ? L10n.tr("教室待确认") : course.room).font(.subheadline.weight(.medium))
                            if !course.building.isEmpty { Text(course.building).font(.caption).foregroundStyle(.secondary) }
                        }.fixedSize(horizontal: false, vertical: true)
                    } icon: { Image(systemName: "mappin.and.ellipse") }
                    .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(14).cardBackground(corner: 16)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(Theme.accent.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
    }
}

struct TimetableImportView: View {
    var automatic = false
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @State private var draft: TimetableSnapshot?
    @State private var from = Date()
    @State private var until = CampusDate.calendar.date(byAdding: .month, value: 4, to: Date())!
    @State private var busy = false
    @State private var error: String?
    @State private var saved = false
    @State private var showPortal = false
    @State private var confirmClear = false
    @State private var confirmReplace = false
    @State private var started = false
    @State private var recognitionStatus = "正在打开门户课表…"
    var body: some View {
        let _ = nativeLocale.identifier

        Form {
            Section {
                Button { beginImport() } label: {
                    Label(L10n.tr("从门户导入课表"), systemImage: "square.and.arrow.down")
                }.disabled(busy || app.lock.isLocked || app.isClearingData)
            } footer: { Text(L10n.tr("自动打开门户课表并识别已选课程，核对后保存到本机。若登录已过期，请先在门户完成登录，识别会自动继续。")) }
            if let error { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.orange) } }
            if let draft {
                Section(L10n.tr("核对适用日期")) {
                    Text(draft.semester).font(.headline)
                    DatePicker(L10n.tr("开始日期"), selection: $from, displayedComponents: .date)
                    DatePicker(L10n.tr("结束日期"), selection: $until, in: from..., displayedComponents: .date)
                }.environment(\.timeZone, CampusDate.calendar.timeZone)
                Section(L10n.format("核对课程（%@ 项）", String(draft.courses.count))) {
                    ForEach(draft.courses) { course in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(course.name).font(.headline)
                            Text("\(weekdayName(course.weekday)) · \(course.start)–\(course.end) · \(course.group)").font(.subheadline).foregroundStyle(Theme.accent)
                            Text(course.location.isEmpty ? L10n.tr("教室待确认") : course.location).font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 4)
                    }
                }
                Section {
                    Button(L10n.tr("确认保存到本地课表")) {
                        if app.timetable.snapshot != nil { confirmReplace = true } else { save() }
                    }.disabled(from > until)
                } footer: { Text(L10n.tr("这是所选学期的每周快照。请核对课程、教室及适用日期；假期和调课依已核实校历处理，临时停课仍以校方通知为准。")) }
            }
            if saved { Section { Label(L10n.tr("已保存到 我的／本地课表"), systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent) } }
            Section {
                NavigationLink(L10n.tr("查看本地课表")) { LocalTimetableView(store: app.timetable) }
                if app.timetable.snapshot != nil { Button(L10n.tr("删除本地课表"), role: .destructive) { confirmClear = true } }
            }
        }.navigationTitle(L10n.tr("提取课表到本地")).navigationBarTitleDisplayMode(.inline)
        .task {
            if automatic && !started { started = true; beginImport() }
        }
        .sheet(isPresented: $showPortal) {
            NavigationStack {
                SiteBrowserView(site: .portal)
                    .safeAreaInset(edge: .top) {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text(L10n.tr(recognitionStatus)).font(.footnote)
                        }.frame(maxWidth: .infinity).padding(12).background(.regularMaterial)
                    }
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("取消")) { showPortal = false } }
                    }
            }.task { await recognizeAutomatically() }
        }
        .confirmationDialog(L10n.tr("替换现有本地课表？"), isPresented: $confirmReplace, titleVisibility: .visible) { Button(L10n.tr("替换课表")) { save() }; Button(L10n.tr("取消"), role: .cancel) {} }
        .confirmationDialog(L10n.tr("删除本机保存的课表？"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button(L10n.tr("删除课表"), role: .destructive) { do { try app.timetable.clear(); saved = false; draft = nil } catch { self.error = L10n.tr("删除失败，请重试。") } }
            Button(L10n.tr("取消"), role: .cancel) {}
        }
    }
    private func beginImport() {
        guard !app.lock.isLocked, app.lock.isActive, !app.isClearingData else { return }
        error = nil; draft = nil; saved = false
        recognitionStatus = "正在打开门户课表…"
        app.browser(for: .portal).load(URL(string: "https://students.gtiit.edu.cn/enrollments")!)
        showPortal = true
    }
    @MainActor private func recognizeAutomatically() async {
        busy = true
        defer { busy = false }
        let browser = app.browser(for: .portal)
        var previous: [String]?
        var restoredEnrollments = false
        for _ in 0..<240 {
            guard !Task.isCancelled, showPortal else { return }
            guard !app.lock.isLocked, app.lock.isActive, !app.isClearingData else {
                showPortal = false
                error = L10n.tr("导入已暂停，请返回前台后重新导入。")
                return
            }
            // Some SSO callbacks land on Dashboard rather than the requested route.
            // Resume only after the portal's own signed-in navigation is present.
            if !restoredEnrollments, !browser.isLoading,
               let url = browser.webView.url, url.host == "students.gtiit.edu.cn",
               url.path == "/" || url.path.isEmpty,
               (try? await browser.webView.evaluateJavaScript("!!document.querySelector('a[href=\"/enrollments\"]')")) as? Bool == true {
                restoredEnrollments = true
                browser.load(URL(string: "https://students.gtiit.edu.cn/enrollments")!)
            }
            if let result = try? await TimetableExtractor.extract(from: browser.webView) {
                guard !Task.isCancelled, showPortal, !app.lock.isLocked, app.lock.isActive, !app.isClearingData else { return }
                let signature = [result.semester] + result.courses.map {
                    "\($0.code)|\($0.group)|\($0.weekday)|\($0.start)|\($0.end)|\($0.room)|\($0.building)|\($0.name)"
                }.sorted()
                if previous == signature && !browser.isLoading {
                    apply(result)
                    showPortal = false
                    return
                }
                previous = signature
                recognitionStatus = "正在核对课程与教室…"
            } else {
                previous = nil
                recognitionStatus = "正在等待课表；如有提示，请完成门户登录"
            }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
        guard !Task.isCancelled else { return }
        error = L10n.tr("暂未识别到完整课表。请确认已登录并有正式选课，然后重新导入。")
        showPortal = false
    }
    private func apply(_ result: TimetableExtractor.Result) {
        let year = String(result.semester.prefix(4))
        let season = result.semester.uppercased().contains("SPRING") ? "Spring" : result.semester.uppercased().contains("SUMMER") ? "Summer" : "Winter"
        let events = AcademicCalendarStore.events.filter { $0.year.hasPrefix(year) }
        let first = events.first { $0.en == (season + " semester begins") }
        let last = events.first { $0.en == (season + " teaching ends") }
        from = first?.startDate ?? Date()
        until = last?.endDate ?? CampusDate.calendar.date(byAdding: .month, value: 4, to: from)!
        draft = TimetableSnapshot(semester: result.semester, validFrom: CampusDate.key(from), validUntil: CampusDate.key(until), courses: result.courses.map(\.local))
    }
    private func save() {
        guard var value = draft, !app.lock.isLocked, app.lock.isActive else { return }
        value.validFrom = CampusDate.key(from); value.validUntil = CampusDate.key(until)
        do { try app.timetable.save(value); draft = nil; saved = true }
        catch { self.error = L10n.tr("保存失败，原有课表保持不变，请重试。") }
    }
}
func weekdayName(_ iso: Int) -> String {
    let names = L10n.isEnglish ? ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"] : [L10n.tr("周一"),L10n.tr("周二"),L10n.tr("周三"),L10n.tr("周四"),L10n.tr("周五"),L10n.tr("周六"),L10n.tr("周日")]
    return names[max(0, min(6, iso - 1))]
}
