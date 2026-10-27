import SwiftUI
import UIKit

struct MyTabView: View {
    @Environment(\.locale) private var nativeLocale
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @State private var showSettings = false
    @State private var rootVisible = true
    @State private var serviceRoute: CampusWebRoute?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var navigationEpoch = UUID()
    var body: some View {
        let _ = nativeLocale.identifier

        NavigationStack {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Color.clear.frame(height: 0).id("me.top")
                    ForEach(settings.mySectionOrder.filter { !settings.hiddenMySections.contains($0) }, id: \.self) { id in
                        switch MyPageSection(rawValue: id) {
                        case .timetable: LocalTimetableEntry(store: app.timetable)
                        case .assignments: MoodleUpcomingEntry(store: app.upcoming)
                        case .exams: StudentExamsEntry(store: app.exams)
                        case .shortcuts: CampusShortcutsSection()
                        case .none: EmptyView()
                        }
                    }
                    MyUtilitiesSection()
                }
                .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 20)
                .frame(maxWidth: 720).frame(maxWidth: .infinity)
            }
            .background(Theme.pageBackground)
            .navigationTitle(L10n.tr("我的"))
            .navigationBarTitleDisplayMode(.large).nativeNavigationSurface(large: true)
            .onAppear { rootVisible = true; app.downloads.dismissCompletedPresentation() }
            .onDisappear { rootVisible = false }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape").frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(L10n.tr("设置"))
                }
            }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(isPresented: Binding(get: { serviceRoute != nil }, set: { if !$0 { serviceRoute = nil } })) {
                if let route = serviceRoute { ServiceCenterView(url: route.url) }
            }
            .onChange(of: app.pendingWebRoute, initial: true) { _, route in
                guard let route, route.site == .serviceHub else { return }
                serviceRoute = route; app.pendingWebRoute = nil
            }
            .task {
                #if DEBUG
                    if ProcessInfo.processInfo.environment["GTIIT_SETTINGS"] == "1" { showSettings = true }
                #endif
            }
            .onChange(of: app.tabReselectToken) { _, _ in
                guard app.tabReselectTarget == .me, rootVisible else { return }
                withAnimation(PrimaryNavigationMotion.animation(reduceMotion: reduceMotion)) {
                    proxy.scrollTo("me.top", anchor: .top)
                }
            }
            }
        }
        .id(navigationEpoch)
        .onChange(of: app.tabReselectToken) { _, _ in
            if app.tabReselectTarget == .me, !rootVisible { showSettings = false; navigationEpoch = UUID() }
        }
    }
}

/// Shared by the Me page and the isolated visual review host.
struct CampusShortcutsSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openURL) private var openURL
    @State private var editing = false
    @State private var calendar = false
    private var shortcuts: [CampusShortcut] {
        settings.shortcutOrder.compactMap { id in CampusShortcut.all.first { $0.id == id && settings.shortcutIDs.contains(id) } }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.tr("常用入口")).font(.headline)
                Spacer()
                Button(L10n.tr(editing ? "完成" : "编辑")) { Haptics.selection(); withAnimation(.snappy(duration: 0.22)) { editing.toggle() } }.font(.subheadline)
            }.padding(.top, 8).padding(.horizontal, 2)
            if shortcuts.isEmpty || editing {
                NavigationLink { ShortcutSettingsView() } label: { Label(L10n.tr("添加常用入口"), systemImage: "plus.circle") }
            }
            ShortcutCollection(items: shortcuts, editing: editing, accessible: dynamicTypeSize.isAccessibilitySize,
                activate: { shortcut in
                    if shortcut.id == "native.calendar" { calendar = true }
                    else if shortcut.id == "native.mail" { openMailAssistant() }
                    else if let link = shortcut.link { app.open(link) }
                    else { app.select(tab: .shuttle) }
                }, remove: { settings.shortcutIDs.remove($0) }, reorder: { ids in
                    // Hidden shortcuts retain their position relative to each other.
                    settings.shortcutOrder = ids + settings.shortcutOrder.filter { !ids.contains($0) }
                }, beginEditing: { editing = true }, contextChanged: { active in
                    if active { app.showContextMenu("shortcuts") } else { app.hideContextMenu("shortcuts") }
                })
                .frame(height: gridHeight)
        }.navigationDestination(isPresented: $calendar) { AcademicCalendarView() }
    }
    private var gridHeight: CGFloat {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let rows = (shortcuts.count + columns - 1) / columns
        let height: CGFloat = dynamicTypeSize.isAccessibilitySize ? 180 : 120
        return CGFloat(rows) * height + CGFloat(max(0, rows - 1)) * 12
    }

    private func openMailAssistant() {
        guard let outlook = URL(string: "ms-outlook://") else { return }
        openURL(outlook) { accepted in
            guard !accepted, let web = URL(string: "https://outlook.office.com/mail/") else { return }
            openURL(web)
        }
    }

}

private struct MyUtilitiesSection: View {
    @EnvironmentObject private var app: AppModel
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink { DownloadsView(center: app.downloads) } label: { MyUtilityRow(title: L10n.tr("下载管理"), symbol: "arrow.down.circle") }
            Divider().padding(.leading, 50)
            NavigationLink { SettingsView() } label: { MyUtilityRow(title: L10n.tr("设置"), symbol: "gearshape") }
            Divider().padding(.leading, 50)
            NavigationLink { HelpView() } label: { MyUtilityRow(title: L10n.tr("帮助与诊断"), symbol: "questionmark.circle") }
        }.buttonStyle(CardPressStyle()).cardBackground().padding(.top, 8)
    }
}

private struct LocalTimetableEntry: View {
    @Environment(\.locale) private var nativeLocale
    @ObservedObject var store: LocalTimetableStore
    @State private var importing = false
    var body: some View {
        let _ = nativeLocale.identifier
        Group {
            if store.snapshot != nil {
                NavigationLink { LocalTimetableView(store: store) } label: {
                    TodayTimetableCard(store: store)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
                }
                    .buttonStyle(CardPressStyle())
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    TodayTimetableCard(store: store)
                    Button { importing = true } label: {
                        Label(L10n.tr("从门户导入课表"), systemImage: "square.and.arrow.down")
                    }.buttonStyle(.borderedProminent).tint(Theme.accent)
                }.padding(.vertical, 6).padding(18).frame(maxWidth: .infinity, alignment: .leading).cardBackground()
            }
        }.sheet(isPresented: $importing) { TimetableImportView(automatic: true) }
    }
}

/// A blue palette with a clear progression between rows and consistent white ink.
private struct CampusShortcutTile: View {
    @Environment(\.colorScheme) private var scheme
    let title: String
    let symbol: String
    let tone: Int
    private var colors: [Color] {
        let rows: [(Double, Double, Double)] = scheme == .dark ? [
            (0.025, 0.23, 0.46), (0.035, 0.27, 0.51), (0.045, 0.31, 0.56),
            (0.055, 0.35, 0.61), (0.070, 0.39, 0.66)
        ] : [
            (0.06, 0.39, 0.70), (0.075, 0.44, 0.74), (0.09, 0.48, 0.78),
            (0.11, 0.51, 0.80), (0.13, 0.54, 0.82)
        ]
        let c = rows[min(tone / 2, rows.count - 1)]
        let right = tone % 2 == 1
        let r = c.0 + (right ? 0.018 : 0)
        let g = c.1 - (right ? 0.018 : 0)
        let b = c.2 + (right ? 0.025 : 0)
        return [Color(red: r + 0.012, green: g + 0.012, blue: b + 0.015),
                Color(red: max(0, r - 0.020), green: g - 0.020, blue: b - 0.015)]
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .font(.system(size: 25, weight: .medium))
                .frame(width: 30, height: 30, alignment: .leading)
                .accessibilityHidden(true)
            Text(title).font(.body.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16).foregroundStyle(.white)
        .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: Theme.shortcutCorner, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.shortcutCorner, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct MyUtilityRow: View {
    let title: String
    let symbol: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Theme.accent).frame(width: 24)
            Text(title).foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
        }.font(.body).frame(minHeight: 50).padding(.horizontal, 16).padding(.vertical, 2)
            .contentShape(Rectangle())
    }
}

private struct ShortcutSizeKey: PreferenceKey {
    static var defaultValue: [String: CGSize] { [:] }
    static func reduce(value: inout [String: CGSize], nextValue: () -> [String: CGSize]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}
/// UIKit arbitrates a stationary long press versus lift-and-move. No extra
/// recognizer competes with the system menu or the parent page's scrolling.
private struct ShortcutCollection: UIViewControllerRepresentable {
    let items: [CampusShortcut]
    let editing: Bool
    let accessible: Bool
    let activate: (CampusShortcut) -> Void
    let remove: (String) -> Void
    let reorder: ([String]) -> Void
    let beginEditing: () -> Void
    let contextChanged: (Bool) -> Void
    func makeUIViewController(context: Context) -> ShortcutGridController { ShortcutGridController(owner: self) }
    func updateUIViewController(_ controller: ShortcutGridController, context: Context) { controller.update(self) }
}
private final class ShortcutGridController: UICollectionViewController, UICollectionViewDelegateFlowLayout, UICollectionViewDragDelegate, UICollectionViewDropDelegate {
    var owner: ShortcutCollection
    private var items: [CampusShortcut]
    private var menuOpen = false
    private var deferredUpdate = false
    private var width: CGFloat = 0
    init(owner: ShortcutCollection) {
        self.owner = owner; items = owner.items
        let layout = UICollectionViewFlowLayout(); layout.minimumInteritemSpacing = 12; layout.minimumLineSpacing = 12
        super.init(collectionViewLayout: layout)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .clear; collectionView.isScrollEnabled = false
        collectionView.clipsToBounds = false; collectionView.dragInteractionEnabled = true
        collectionView.dragDelegate = self; collectionView.dropDelegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "shortcut")
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if width != collectionView.bounds.width { width = collectionView.bounds.width; collectionView.collectionViewLayout.invalidateLayout() }
    }
    func update(_ value: ShortcutCollection) {
        let changed = value.items.map { $0.id + $0.title } != items.map { $0.id + $0.title } || owner.editing != value.editing || owner.accessible != value.accessible
        owner = value
        guard isViewLoaded, changed else { return }
        if menuOpen { deferredUpdate = true; return }
        items = owner.items; collectionView.reloadData(); collectionView.collectionViewLayout.invalidateLayout()
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "shortcut", for: indexPath)
        let item = items[indexPath.item], remove = owner.remove, editing = owner.editing
        cell.backgroundColor = .clear; cell.contentView.backgroundColor = .clear
        cell.isAccessibilityElement = !editing
        cell.accessibilityLabel = item.title
        cell.accessibilityTraits = .button
        cell.accessibilityCustomActions = editing ? [] : [
            UIAccessibilityCustomAction(name: L10n.tr("编辑")) { [weak self] _ in self?.owner.beginEditing(); return true },
            UIAccessibilityCustomAction(name: L10n.tr("从常用入口移除")) { [weak self] _ in self?.owner.remove(item.id); return true },
            UIAccessibilityCustomAction(name: L10n.tr("向前移动")) { [weak self] _ in self?.moveAccessible(item.id, offset: -1) ?? false },
            UIAccessibilityCustomAction(name: L10n.tr("向后移动")) { [weak self] _ in self?.moveAccessible(item.id, offset: 1) ?? false }
        ]
        cell.contentConfiguration = UIHostingConfiguration {
            CampusShortcutTile(title: item.title, symbol: item.symbol, tone: indexPath.item)
                .overlay(alignment: .topTrailing) {
                    if editing {
                        Button { Haptics.selection(); remove(item.id) } label: {
                            Image(systemName: "minus").font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white).frame(width: 23, height: 23).background(Color(uiColor: .systemRed), in: Circle())
                                .frame(width: 44, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel(L10n.tr("从常用入口移除") + " " + item.title)
                    }
                }
        }.margins(.all, 0)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: max(1, owner.accessible ? collectionView.bounds.width : (collectionView.bounds.width - 12) / 2), height: owner.accessible ? 180 : 120)
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard !owner.editing, items.indices.contains(indexPath.item) else { return }
        Haptics.light(); owner.activate(items[indexPath.item])
    }
    private func moveAccessible(_ id: String, offset: Int) -> Bool {
        guard let source = items.firstIndex(where: { $0.id == id }), items.indices.contains(source + offset) else { return false }
        let target = source + offset
        let item = items.remove(at: source); items.insert(item, at: target)
        owner.reorder(items.map(\.id)); collectionView.reloadData(); Haptics.selection()
        return true
    }
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard !owner.editing, indexPaths.count == 1, let path = indexPaths.first, items.indices.contains(path.item) else { return nil }
        let item = items[path.item]
        // No separate, rescaled preview: the actual source view is lifted with
        // the same continuous 24pt path used by the card and dismissal.
        return UIContextMenuConfiguration(identifier: item.id as NSString, previewProvider: nil) { [weak self] _ in
            guard let self else { return UIMenu() }
            var actions: [UIMenuElement] = []
            if let url = item.link?.url {
                actions.append(UIAction(title: L10n.tr("分享"), image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                    guard let self else { return }
                    let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    sheet.popoverPresentationController?.sourceView = self.collectionView.cellForItem(at: path)
                    self.present(sheet, animated: true)
                })
            }
            actions.append(UIAction(title: L10n.tr("编辑"), image: UIImage(systemName: "square.and.pencil")) { _ in self.owner.beginEditing() })
            actions.append(UIAction(title: L10n.tr("从常用入口移除"), image: UIImage(systemName: "minus.circle"), attributes: .destructive) { _ in self.owner.remove(item.id) })
            return UIMenu(children: actions)
        }
    }
    private func preview(_ path: IndexPath) -> UITargetedPreview? {
        guard let cell = collectionView.cellForItem(at: path), cell.window != nil else { return nil }
        let parameters = UIPreviewParameters(); parameters.backgroundColor = .clear
        let outline = UIBezierPath(cgPath: RoundedRectangle(cornerRadius: Theme.shortcutCorner, style: .continuous).path(in: cell.contentView.bounds).cgPath)
        parameters.visiblePath = outline; parameters.shadowPath = outline
        return UITargetedPreview(view: cell.contentView, parameters: parameters)
    }
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, highlightPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? { preview(indexPath) }
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, dismissalPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? { preview(indexPath) }
    override func collectionView(_ collectionView: UICollectionView, willDisplayContextMenu configuration: UIContextMenuConfiguration, animator: (any UIContextMenuInteractionAnimating)?) {
        menuOpen = true; owner.contextChanged(true)
    }
    override func collectionView(_ collectionView: UICollectionView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: (any UIContextMenuInteractionAnimating)?) {
        let finish = { [weak self] in
            guard let self else { return }; self.menuOpen = false; self.owner.contextChanged(false)
            if self.deferredUpdate { self.deferredUpdate = false; self.items = self.owner.items; self.collectionView.reloadData() }
        }
        if let animator { animator.addCompletion(finish) } else { finish() }
    }
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: any UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard items.indices.contains(indexPath.item) else { return [] }
        let id = items[indexPath.item].id
        let drag = UIDragItem(itemProvider: NSItemProvider(object: id as NSString)); drag.localObject = id
        return [drag]
    }
    func collectionView(_ collectionView: UICollectionView, dragSessionIsRestrictedToDraggingApplication session: any UIDragSession) -> Bool { true }
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        let parameters = UIDragPreviewParameters(); parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(cgPath: RoundedRectangle(cornerRadius: Theme.shortcutCorner, style: .continuous).path(in: cell.bounds).cgPath)
        return parameters
    }
    func collectionView(_ collectionView: UICollectionView, dragSessionWillBegin session: any UIDragSession) { owner.contextChanged(false); Haptics.medium() }
    func collectionView(_ collectionView: UICollectionView, canHandle session: any UIDropSession) -> Bool { session.localDragSession != nil && session.items.allSatisfy { $0.localObject is String } }
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: any UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        UICollectionViewDropProposal(operation: session.localDragSession == nil ? .forbidden : .move, intent: .insertAtDestinationIndexPath)
    }
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: any UICollectionViewDropCoordinator) {
        guard let dropped = coordinator.items.first, let source = dropped.sourceIndexPath, items.indices.contains(source.item) else { return }
        let target = min(max(0, coordinator.destinationIndexPath?.item ?? items.count - 1), items.count - 1)
        guard source.item != target else { coordinator.drop(dropped.dragItem, toItemAt: source); return }
        let item = items.remove(at: source.item); items.insert(item, at: target)
        collectionView.performBatchUpdates {
            collectionView.deleteItems(at: [source]); collectionView.insertItems(at: [IndexPath(item: target, section: 0)])
        } completion: { [weak self] _ in
            guard let self else { return }; self.owner.reorder(self.items.map(\.id)); Haptics.selection()
            self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
        }
        coordinator.drop(dropped.dragItem, toItemAt: IndexPath(item: target, section: 0))
    }
}
