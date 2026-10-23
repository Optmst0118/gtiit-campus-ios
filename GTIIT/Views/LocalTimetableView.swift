import SwiftUI

struct TodayTimetableCard: View {
    @Environment(\.locale) private var nativeLocale
    @ObservedObject var store: LocalTimetableStore
    var body: some View {
        let _ = nativeLocale.identifier
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(L10n.tr("本地课表"), systemImage: "calendar").font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
                if let snapshot = store.snapshot {
                    if let (course, date) = snapshot.next(after: context.date) {
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 16) {
                                time(course)
                                details(course, date: date)
                            }
                            VStack(alignment: .leading, spacing: 8) { time(course); details(course, date: date) }
                        }
                        let remaining = snapshot.courses(on: context.date).filter { $0.id != course.id }
                        if let later = remaining.first {
                            Divider()
                            HStack(alignment: .firstTextBaseline) {
                                Text(later.start).monospacedDigit().foregroundStyle(Theme.accent)
                                Text(later.name).lineLimit(2)
                                Spacer(minLength: 0)
                            }.font(.subheadline)
                        } else if snapshot.courses(on: context.date).isEmpty {
                            Text(L10n.tr("今天没有课程")).font(.caption).foregroundStyle(.secondary)
                        }
                    } else { Text(L10n.tr("暂无后续课程")).font(.subheadline).foregroundStyle(.secondary) }
                } else {
                    Text(L10n.tr("从门户导入课表")).font(.subheadline).foregroundStyle(.secondary)
                }
            }.accessibilityElement(children: .combine)
        }
    }
    private func time(_ course: LocalCourse) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(L10n.tr("下一节")).font(.caption.weight(.medium))
            Text(course.start).font(.title2.weight(.semibold).monospacedDigit())
            Text(course.end).font(.caption.monospacedDigit()).foregroundStyle(Color(uiColor: .secondaryLabel))
        }.foregroundStyle(Theme.accent).fixedSize(horizontal: true, vertical: false)
    }
    private func details(_ course: LocalCourse, date: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(course.name).font(.headline).fixedSize(horizontal: false, vertical: true)
            Text(CampusDate.display(date, weekday: true)).font(.caption).foregroundStyle(.secondary)
            Label(course.room.isEmpty ? L10n.tr("教室待确认") : course.room, systemImage: "mappin.and.ellipse")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(course.location)
            if !course.building.isEmpty { Text(course.building).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
        }.frame(maxWidth: .infinity, alignment: .leading)
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
        .sheet(isPresented: $showImport) { TimetableImportView() }
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

/// Settings uses the same push navigation as its other peers. Only the import
/// operation opens a dedicated flow; local management remains in this hierarchy.
struct TimetableSettingsView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.locale) private var nativeLocale
    @State private var importing = false
    @State private var clear = false
    @State private var error: String?
    var body: some View {
        let _ = nativeLocale.identifier
        Form {
            Section {
                Button { importing = true } label: {
                    Label(L10n.tr("提取课表到本地"), systemImage: "square.and.arrow.down")
                }
            } footer: { Text(L10n.tr("使用门户现有登录，识别后进入核对页。只有点击右上角蓝色勾后才保存。")) }
            if app.timetable.snapshot != nil {
                Section {
                    NavigationLink(L10n.tr("查看本地课表")) { LocalTimetableView(store: app.timetable) }
                    Button(L10n.tr("删除本地课表"), role: .destructive) { clear = true }
                }
            }
            if let error { Text(error).foregroundStyle(Theme.orange) }
        }
        .scrollContentBackground(.hidden).background(Theme.pageBackground)
        .navigationTitle(L10n.tr("课表")).navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $importing) { TimetableImportView(automatic: true) }
        .confirmationDialog(L10n.tr("删除本机保存的课表？"), isPresented: $clear, titleVisibility: .visible) {
            Button(L10n.tr("删除课表"), role: .destructive) {
                do { try app.timetable.clear() } catch { self.error = L10n.tr("删除失败，请重试。") }
            }
        }
    }
}

struct TimetableImportView: View {
    private enum Step: Hashable { case portal, review }
    private let automatic: Bool
    @Environment(\.locale) private var nativeLocale
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var app: AppModel
    @State private var path: [Step]
    @State private var draft: TimetableSnapshot?
    @State private var from: Date
    @State private var until: Date
    @State private var busy = false
    @State private var error: String?
    @State private var confirmClear = false
    @State private var confirmReplace = false
    @State private var started = false
    @State private var shouldRecognize = false
    @State private var recognitionID = UUID()
    @State private var recognitionStatus = "正在打开门户课表…"

    init(automatic: Bool = false, initialDraft: TimetableSnapshot? = nil) {
        self.automatic = automatic
        _draft = State(initialValue: initialDraft)
        _path = State(initialValue: initialDraft == nil ? [] : [.portal, .review])
        let first = initialDraft.flatMap { CampusDate.parse($0.validFrom) } ?? Date()
        _from = State(initialValue: first)
        _until = State(initialValue: initialDraft.flatMap { CampusDate.parse($0.validUntil) }
            ?? CampusDate.calendar.date(byAdding: .month, value: 4, to: first)!)
    }
    private var canSave: Bool {
        draft != nil && !busy && from <= until && !app.lock.isLocked && app.lock.isActive && !app.isClearingData
    }
    var body: some View {
        let _ = nativeLocale.identifier
        NavigationStack(path: $path) {
            Form {
                Section {
                    Label(L10n.tr("识别门户课表"), systemImage: "1.circle.fill")
                    Label(L10n.tr("核对课程并保存"), systemImage: "2.circle.fill")
                } footer: { Text(L10n.tr("使用门户现有登录，识别后进入核对页。只有点击右上角蓝色勾后才保存。")) }
                Section {
                    Button { beginImport() } label: {
                        Label(L10n.tr("从门户导入课表"), systemImage: "square.and.arrow.down")
                    }.disabled(busy || app.lock.isLocked || app.isClearingData)
                } footer: { Text(L10n.tr("若登录已过期，请先在门户完成登录，识别会自动继续。")) }
                if let error { errorSection(error) }
                if app.timetable.snapshot != nil {
                    Section {
                        NavigationLink(L10n.tr("查看本地课表")) { LocalTimetableView(store: app.timetable) }
                        Button(L10n.tr("删除本地课表"), role: .destructive) { confirmClear = true }
                    }
                }
            }
            .navigationTitle(L10n.tr("提取课表到本地")).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { backButton { dismiss() } } }
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .portal: portal
                case .review: review
                }
            }
        }
        .tint(Theme.accent)
        .task { if automatic && !started { started = true; beginImport() } }
        .onChange(of: from) { _, value in if until < value { until = value } }
        .confirmationDialog(L10n.tr("替换现有本地课表？"), isPresented: $confirmReplace, titleVisibility: .visible) {
            Button(L10n.tr("替换课表")) { save() }
            Button(L10n.tr("取消"), role: .cancel) {}
        }
        .confirmationDialog(L10n.tr("删除本机保存的课表？"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button(L10n.tr("删除课表"), role: .destructive) {
                do { try app.timetable.clear(); draft = nil } catch { self.error = L10n.tr("删除失败，请重试。") }
            }
            Button(L10n.tr("取消"), role: .cancel) {}
        }
    }
    private var portal: some View {
        SiteBrowserView(site: .portal)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 10) {
                    if busy { ProgressView() }
                    Text(L10n.tr(busy ? recognitionStatus : "可调整学期，然后重新识别课表"))
                        .font(.footnote).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    if !busy, draft != nil {
                        Button(L10n.tr("核对")) { path.append(.review) }.font(.footnote.weight(.semibold))
                    }
                }.padding(12).background(.regularMaterial)
            }
            .navigationTitle(L10n.tr("门户课表")).navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { backButton { shouldRecognize = false; path = [] } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.tr("重新识别")) {
                        error = nil; draft = nil; shouldRecognize = true; recognitionID = UUID()
                    }.disabled(busy || app.lock.isLocked || app.isClearingData)
                }
            }
            .task(id: recognitionID) { if shouldRecognize { await recognizeAutomatically() } }
    }
    private var review: some View {
        Form {
            if let draft {
                Section {
                    Label(L10n.format("已识别 %@ 项课程", String(draft.courses.count)), systemImage: "checkmark.circle")
                        .foregroundStyle(Theme.accent)
                    Text(draft.semester).font(.subheadline).foregroundStyle(.secondary)
                } footer: { Text(L10n.tr("核对无误后，点击右上角蓝色勾保存到本机。")) }
                Section(L10n.tr("核对适用日期")) {
                    DatePicker(L10n.tr("开始日期"), selection: $from, displayedComponents: .date)
                    DatePicker(L10n.tr("结束日期"), selection: $until, in: from..., displayedComponents: .date)
                }.environment(\.timeZone, CampusDate.calendar.timeZone)
                if let error { errorSection(error) }
                Section {
                    ForEach(draft.courses) { course in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(course.name).font(.headline)
                            Text("\(weekdayName(course.weekday)) · \(course.start)–\(course.end) · \(course.group)")
                                .font(.subheadline).foregroundStyle(Theme.accent)
                            Text(course.location.isEmpty ? L10n.tr("教室待确认") : course.location)
                                .font(.subheadline).foregroundStyle(.secondary)
                        }.padding(.vertical, 5)
                    }
                } header: { Text(L10n.format("核对课程（%@ 项）", String(draft.courses.count))) }
                footer: { Text(L10n.tr("这是所选学期的每周快照。请核对课程、教室及适用日期；假期和调课依已核实校历处理，临时停课仍以校方通知为准。")) }
            }
        }
        .navigationTitle(L10n.tr("核对课表")).navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { backButton { _ = path.popLast() } }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    if app.timetable.snapshot != nil { confirmReplace = true } else { save() }
                } label: {
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).frame(minWidth: 44, minHeight: 44)
                }.tint(Theme.accent).disabled(!canSave)
                    .accessibilityLabel(L10n.tr("确认保存到本地课表"))
            }
        }
    }
    private func backButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                Text(L10n.tr("返回"))
            }
        }
    }
    private func errorSection(_ value: String) -> some View {
        Section { Label(value, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.orange) }
    }
    private func beginImport() {
        guard !app.lock.isLocked, app.lock.isActive, !app.isClearingData else { return }
        error = nil; draft = nil; shouldRecognize = true
        recognitionStatus = "正在打开门户课表…"
        recognitionID = UUID()
        app.browser(for: .portal).load(URL(string: "https://students.gtiit.edu.cn/enrollments")!)
        path = [.portal]
    }
    @MainActor private func recognizeAutomatically() async {
        busy = true
        defer { busy = false }
        let browser = app.browser(for: .portal)
        var previous: [String]?
        var restoredEnrollments = false
        for _ in 0..<240 {
            guard !Task.isCancelled, path.last == .portal else { return }
            guard !app.lock.isLocked, app.lock.isActive, !app.isClearingData else {
                path = []
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
                guard !Task.isCancelled, path.last == .portal, !app.lock.isLocked, app.lock.isActive, !app.isClearingData else { return }
                let signature = [result.semester] + result.courses.map {
                    "\($0.code)|\($0.group)|\($0.weekday)|\($0.start)|\($0.end)|\($0.room)|\($0.building)|\($0.name)"
                }.sorted()
                if previous == signature && !browser.isLoading {
                    apply(result)
                    shouldRecognize = false
                    path.append(.review)
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
        shouldRecognize = false
        path = []
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
        guard canSave, var value = draft else { return }
        value.validFrom = CampusDate.key(from); value.validUntil = CampusDate.key(until)
        do {
            try app.timetable.save(value)
            app.toast(L10n.tr("已保存到 我的／本地课表"))
            dismiss()
        } catch { self.error = L10n.tr("保存失败，原有课表保持不变，请重试。") }
    }
}
func weekdayName(_ iso: Int) -> String {
    let names = L10n.isEnglish ? ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"] : [L10n.tr("周一"),L10n.tr("周二"),L10n.tr("周三"),L10n.tr("周四"),L10n.tr("周五"),L10n.tr("周六"),L10n.tr("周日")]
    return names[max(0, min(6, iso - 1))]
}
