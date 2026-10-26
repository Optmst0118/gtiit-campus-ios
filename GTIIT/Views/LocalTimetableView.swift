import SwiftUI
import UIKit

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
    @State private var selectedDay: String? = CampusDate.key(Date())
    @State private var pagerHeight: CGFloat = 520
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    private var anchor: Date { selectedDay.flatMap(CampusDate.parse) ?? Date() }
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

        GeometryReader { geometry in
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                weekControls
                if let snapshot = store.snapshot {
                    if typeSize.isAccessibilitySize {
                        VStack(spacing: 12) { ForEach(days, id: \.self) { day in dayColumn(day, snapshot: snapshot) } }
                    } else {
                        carousel(snapshot)

                    }
                    Text("\(snapshot.semester) · \(snapshot.validFrom) – \(snapshot.validUntil)").font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
                } else {
                    ContentUnavailableView(L10n.tr("尚无本地课表"), systemImage: "calendar", description: Text(store.loadError ?? L10n.tr("从设置中提取门户课表后，即可离线查看。")))
                    Button(L10n.tr("提取课表")) { showImport = true }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                }
            }.padding(16)
        }.onChange(of: geometry.size.height, initial: true) { _, height in pagerHeight = max(380, height - 114) }
        }.background(Theme.pageBackground).navigationTitle(L10n.tr("整周课表")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(L10n.tr("更新"), systemImage: "arrow.clockwise") { showImport = true } } }
        .sheet(isPresented: $showImport) { TimetableImportView() }
    }
    private func carousel(_ snapshot: TimetableSnapshot) -> some View {
        TimetableDayCarousel(dates: pagerDays, selection: $selectedDay, height: $pagerHeight, reduceMotion: reduceMotion) { day in
            AnyView(Button { select(day) } label: {
                dayColumn(day, snapshot: snapshot, fillHeight: pagerHeight)
            }.buttonStyle(.plain))
        }.frame(height: pagerHeight)
            .mask {
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing).frame(width: 18)
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: 18)
                }
            }
    }
    private var weekControls: some View {
        HStack {
            Button { shift(-7) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }.accessibilityLabel(L10n.tr("上一周"))
            Spacer()
            VStack(spacing: 3) {
                Text(CampusDate.display(days[0])).font(.headline)
                Button(L10n.tr("回到今天")) { select(Date()) }.font(.caption)
            }
            Spacer()
            Button { shift(7) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }.accessibilityLabel(L10n.tr("下一周"))
        }
    }
    private var pagerDays: [Date] {
        let calendar = CampusDate.calendar
        let from = min(store.snapshot.flatMap { CampusDate.parse($0.validFrom) } ?? anchor, calendar.startOfDay(for: Date()))
        let until = max(store.snapshot.flatMap { CampusDate.parse($0.validUntil) } ?? anchor, calendar.startOfDay(for: Date()))
        let first = calendar.date(byAdding: .day, value: -21, to: from)!
        let count = min(1100, (calendar.dateComponents([.day], from: first, to: until).day ?? 0) + 43)
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
    }
    private func select(_ date: Date) {
        let key = CampusDate.key(date)
        guard pagerDays.contains(where: { CampusDate.key($0) == key }) else { return }
        Haptics.selection()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { selectedDay = key }
    }
    private func shift(_ value: Int) {
        guard let date = CampusDate.calendar.date(byAdding: .day, value: value, to: anchor) else { return }
        select(date)
    }
    private func dayColumn(_ day: Date, snapshot: TimetableSnapshot, fillHeight: CGFloat? = nil) -> some View {
        let courses = snapshot.courses(on: day)
        let rowHeight = fillHeight.map { max(72, ($0 - 64 - CGFloat(max(4, courses.count - 1)) * 8) / CGFloat(max(5, courses.count))) }
        return VStack(alignment: .leading, spacing: 8) {
            Text(CampusDate.display(day, weekday: true)).font(.subheadline.weight(.semibold))
                .foregroundStyle(CampusDate.calendar.isDateInToday(day) ? Theme.accent : .primary).padding(.bottom, 4)
            if courses.isEmpty { Text(L10n.tr("无课程")).font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 20) }
            ForEach(courses) { course in
                HStack(alignment: .center, spacing: 10) {
                    VStack(spacing: 3) {
                        Text(course.start).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
                        Text(course.end).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7).allowsTightening(true)
                    }.monospacedDigit().foregroundStyle(Theme.accent).frame(width: typeSize.isAccessibilitySize ? 96 : 55)
                    Capsule().fill(Theme.accent.opacity(0.32)).frame(width: 2, height: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(course.name).font(.subheadline.weight(.semibold)).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        Text([course.room.isEmpty ? L10n.tr("教室待确认") : course.room, course.building].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                        Text([course.code, course.group].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.padding(.horizontal, 10).padding(.vertical, 6)
                    .frame(minHeight: rowHeight, maxHeight: rowHeight, alignment: .center)
                    .cardBackground(corner: 14).accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .frame(minHeight: fillHeight, maxHeight: fillHeight, alignment: .top)
            .background(Theme.accent.opacity(CampusDate.key(day) == selectedDay ? (colorScheme == .dark ? 0.22 : 0.14) : 0.035), in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.accent.opacity(CampusDate.key(day) == selectedDay ? 0.35 : 0), lineWidth: 1) }
            .accessibilityAddTraits(CampusDate.key(day) == selectedDay ? [.isSelected] : [])
    }
}

/// A gesture advances at most one day. Crossing a week requires actual
/// continued travel, never a high-velocity projection into the following week.
enum TimetableDaySnap {
    static let boundaryTravelFraction: CGFloat = 0.60
    static func boundaryOffset(travel: CGFloat, step: CGFloat) -> CGFloat {
        guard step > 0 else { return 0 }
        let length = abs(travel), threshold = step * boundaryTravelFraction
        let distance = min(length, threshold) * 0.50 + max(0, length - threshold)
        return (travel >= 0 ? 1 : -1) * min(step, distance)
    }
    static func index(original: CGFloat, proposed: CGFloat, velocity: CGFloat, step: CGFloat, count: Int,
                      weekday: Int = 0, travel: CGFloat? = nil) -> Int {
        guard step > 0, count > 0 else { return 0 }
        let start = min(count - 1, max(0, Int((original / step).rounded())))
        let distance = travel ?? proposed - original
        let direction = distance >= 0 ? 1 : -1
        let boundary = (weekday == 1 && direction > 0) || (weekday == 2 && direction < 0)
        if boundary && abs(distance) < step * boundaryTravelFraction { return start }
        let candidate = boundary ? start + direction : min(start + 1, max(start - 1, Int((proposed / step).rounded())))
        return min(count - 1, max(0, candidate))
    }
}

/// Reusable cells render only visible dates. UIKit owns finger tracking,
/// velocity and deceleration; selection updates never rebuild a year of views.
private struct TimetableDayCarousel: UIViewControllerRepresentable {
    let dates: [Date]
    @Binding var selection: String?
    @Binding var height: CGFloat
    let reduceMotion: Bool
    let content: (Date) -> AnyView
    func makeUIViewController(context: Context) -> Controller { Controller(owner: self) }
    func updateUIViewController(_ controller: Controller, context: Context) { controller.update(self) }
    final class Controller: UICollectionViewController, UICollectionViewDelegateFlowLayout {
        var owner: TimetableDayCarousel
        private var width: CGFloat = 0
        private var cardWidth: CGFloat { min(350, max(240, width - 44)) }
        private var step: CGFloat { cardWidth + 12 }
        private var startOffset: CGFloat = 0
        private var dragTravel: CGFloat = 0
        private var tracking = false
        private var adjusting = false
        private var selectedKey: String?
        init(owner: TimetableDayCarousel) {
            self.owner = owner
            let layout = UICollectionViewFlowLayout(); layout.scrollDirection = .horizontal
            layout.minimumLineSpacing = 12; layout.minimumInteritemSpacing = 0
            super.init(collectionViewLayout: layout)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidLoad() {
            super.viewDidLoad(); collectionView.backgroundColor = .clear
            collectionView.showsHorizontalScrollIndicator = false; collectionView.decelerationRate = .fast
            collectionView.contentInsetAdjustmentBehavior = .never
            collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "day")
        }
        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            if abs(width - collectionView.bounds.width) > 0.5 {
                width = collectionView.bounds.width; collectionView.collectionViewLayout.invalidateLayout()
                collectionView.layoutIfNeeded(); position(animated: false)
            }
        }
        func update(_ value: TimetableDayCarousel) {
            let changed = selectedKey != value.selection
            let datesChanged = owner.dates != value.dates, heightChanged = owner.height != value.height
            owner = value
            guard isViewLoaded else { return }
            if datesChanged { collectionView.reloadData() }
            if heightChanged { collectionView.collectionViewLayout.invalidateLayout() }
            // Only the two/three visible cells need updated selection colour.
            for path in collectionView.indexPathsForVisibleItems { configure(collectionView.cellForItem(at: path), at: path) }
            if changed, !collectionView.isDragging, !collectionView.isDecelerating { position(animated: !owner.reduceMotion) }
        }
        private func configure(_ cell: UICollectionViewCell?, at path: IndexPath) {
            guard let cell, owner.dates.indices.contains(path.item) else { return }
            let content = owner.content, date = owner.dates[path.item]
            cell.backgroundColor = .clear
            UIView.performWithoutAnimation {
                cell.contentConfiguration = UIHostingConfiguration {
                    content(date).transaction { $0.animation = nil; $0.disablesAnimations = true }
                }.margins(.all, 0)
            }
        }
        override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { owner.dates.count }
        override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "day", for: indexPath); configure(cell, at: indexPath); return cell
        }
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize { CGSize(width: cardWidth, height: max(1, collectionView.bounds.height)) }
        func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
            let edge = max(0, (width - cardWidth) / 2); return UIEdgeInsets(top: 0, left: edge, bottom: 0, right: edge)
        }
        private func position(animated: Bool) {
            guard let index = owner.dates.firstIndex(where: { CampusDate.key($0) == owner.selection }) else { return }
            selectedKey = owner.selection
            collectionView.setContentOffset(CGPoint(x: CGFloat(index) * step, y: 0), animated: animated)
        }
        override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            Haptics.prepare(); tracking = true; dragTravel = 0
            startOffset = scrollView.contentOffset.x
        }
        private var weekday: Int {
            guard !owner.dates.isEmpty else { return 0 }
            let index = min(owner.dates.count - 1, max(0, Int((startOffset / step).rounded())))
            return CampusDate.calendar.component(.weekday, from: owner.dates[index])
        }
        override func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard tracking, !adjusting else { return }
            // Measure the finger directly: feeding our resisted contentOffset back
            // into the next sample amplified travel and weakened the barrier.
            dragTravel = -scrollView.panGestureRecognizer.translation(in: scrollView).x
            guard (weekday == 1 && dragTravel > 0) || (weekday == 2 && dragTravel < 0) else { return }
            adjusting = true
            scrollView.contentOffset.x = startOffset + TimetableDaySnap.boundaryOffset(travel: dragTravel, step: step)
            adjusting = false
        }
        override func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            dragTravel = -scrollView.panGestureRecognizer.translation(in: scrollView).x
            let index = TimetableDaySnap.index(original: startOffset, proposed: targetContentOffset.pointee.x, velocity: velocity.x * 1000,
                step: step, count: owner.dates.count, weekday: weekday, travel: dragTravel)
            targetContentOffset.pointee = CGPoint(x: CGFloat(index) * step, y: 0)
            // Resolve the highlight and haptic at release, not after the final
            // deceleration callback. Scrolling still uses UIKit's native curve.
            commitSelection(index)
        }
        override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { tracking = false; if !decelerate { publish() } }
        override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) { publish() }
        override func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) { publish() }
        private func publish() {
            guard !owner.dates.isEmpty else { return }
            let index = min(owner.dates.count - 1, max(0, Int((collectionView.contentOffset.x / step).rounded())))
            commitSelection(index)
        }
        private func commitSelection(_ index: Int) {
            guard owner.dates.indices.contains(index) else { return }
            let key = CampusDate.key(owner.dates[index]); selectedKey = key
            guard owner.selection != key else { return }
            Haptics.selection()
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { owner.selection = key }
        }
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
        .navigationTitle(L10n.tr("课表")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
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
            .navigationTitle(L10n.tr("提取课表到本地")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
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
            .navigationTitle(L10n.tr("门户课表")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
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
        .navigationTitle(L10n.tr("核对课表")).navigationBarTitleDisplayMode(.inline).nativeNavigationSurface()
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
