import PDFKit
import SwiftUI
import UIKit

/// Real, independent collection cells. A context menu never targets a SwiftUI
/// List row containing several files. UIKit owns lift, backdrop and restoration.
struct DownloadFileGrid: UIViewControllerRepresentable {
    let items: [DownloadItem]
    let center: DownloadCoordinator
    let activate: (DownloadItem) -> Void
    let delete: (DownloadItem) -> Void
    let share: (URL) -> Void
    let openSource: (DownloadItem) -> Void
    func makeUIViewController(context: Context) -> DownloadGridController { DownloadGridController(owner: self) }
    func updateUIViewController(_ controller: DownloadGridController, context: Context) { controller.update(self) }
}

final class DownloadGridController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    private var owner: DownloadFileGrid
    private var displayedItems: [DownloadItem]
    private var menuOpen = false
    private var needsReload = false
    private var layoutWidth: CGFloat = 0
    private var layoutCategory: UIContentSizeCategory?
    init(owner: DownloadFileGrid) {
        self.owner = owner
        self.displayedItems = owner.items
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16; layout.minimumLineSpacing = 24
        // Reserve room above the first thumbnail for UIKit's native lift/shadow.
        // Keeping the source away from the scroll viewport edge prevents an
        // apparent cut in the upper blur during the intermediate press phase.
        layout.sectionInset = UIEdgeInsets(top: 24, left: 20, bottom: 28, right: 20)
        super.init(collectionViewLayout: layout)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.allowsMultipleSelection = false
        collectionView.register(DownloadDocumentCell.self, forCellWithReuseIdentifier: "document")
    }
    func update(_ owner: DownloadFileGrid) {
        let before = displayedItems.map { "\($0.id)-\($0.state)-\($0.progress)-\($0.filename)" }
        let after = owner.items.map { "\($0.id)-\($0.state)-\($0.progress)-\($0.filename)" }
        self.owner = owner
        guard before != after else { return }
        // Do not replace or recycle a menu's source view until UIKit restores it.
        if menuOpen { needsReload = true } else { displayedItems = owner.items; collectionView.reloadData() }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if abs(layoutWidth - collectionView.bounds.width) > 0.5 || layoutCategory != traitCollection.preferredContentSizeCategory {
            layoutWidth = collectionView.bounds.width
            layoutCategory = traitCollection.preferredContentSizeCategory
            collectionView.collectionViewLayout.invalidateLayout()
        }
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { displayedItems.count }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "document", for: indexPath) as! DownloadDocumentCell
        let item = displayedItems[indexPath.item]
        cell.configure(item, url: item.state == .completed ? owner.center.fileURL(for: item) : nil)
        return cell
    }
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let accessible = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let width = collectionView.bounds.width
        let count = accessible ? (width > 600 ? 2 : 1) : max(2, Int((width - 24) / 122))
        let cellWidth = floor((width - 40 - CGFloat(count - 1) * 16) / CGFloat(count))
        let labelHeight = ceil(UIFont.preferredFont(forTextStyle: .caption1).lineHeight * 2)
        return CGSize(width: max(72, cellWidth), height: 88 + 10 + labelHeight + 18)
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard displayedItems.indices.contains(indexPath.item) else { return }
        owner.activate(displayedItems[indexPath.item])
    }
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemsAt indexPaths: [IndexPath], point: CGPoint) -> UIContextMenuConfiguration? {
        guard indexPaths.count == 1, let path = indexPaths.first, displayedItems.indices.contains(path.item) else { return nil }
        let item = displayedItems[path.item]
        let url = item.state == .completed ? owner.center.fileURL(for: item) : nil
        return UIContextMenuConfiguration(identifier: item.id.uuidString as NSString, previewProvider: {
            guard let url else { return nil }
            let controller = UIHostingController(rootView: DownloadContextPreview(source: url, filename: item.filename))
            controller.preferredContentSize = CGSize(width: 300, height: 420)
            return controller
        }, actionProvider: { [weak self] _ in
            guard let self else { return UIMenu() }
            var actions: [UIMenuElement] = []
            if item.state == .completed {
                actions.append(UIAction(title: L10n.tr("预览"), image: UIImage(systemName: "doc.text.magnifyingglass")) { _ in self.owner.activate(item) })
                if let url { actions.append(UIAction(title: L10n.tr("分享"), image: UIImage(systemName: "square.and.arrow.up")) { _ in self.owner.share(url) }) }
            } else if item.state == .downloading {
                actions.append(UIAction(title: L10n.tr("取消下载"), image: UIImage(systemName: "xmark.circle")) { _ in self.owner.center.cancel(item.id) })
            } else if self.owner.center.canRetry(item.id) {
                actions.append(UIAction(title: L10n.tr("继续下载"), image: UIImage(systemName: "arrow.clockwise")) { _ in self.owner.center.retry(item.id) })
            } else {
                actions.append(UIAction(title: L10n.tr("打开来源站点"), image: UIImage(systemName: "safari")) { _ in self.owner.openSource(item) })
            }
            actions.append(UIAction(title: L10n.tr("删除"), image: UIImage(systemName: "trash"), attributes: .destructive) { _ in self.owner.delete(item) })
            return UIMenu(children: actions)
        })
    }
    private func documentPreview(_ indexPath: IndexPath) -> UITargetedPreview? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? DownloadDocumentCell, cell.paper.window != nil else { return nil }
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: cell.paper.bounds, cornerRadius: 4)
        // Inset only the shadow source: keep the full paper visible while
        // reducing the dark halo during both native lift and restoration.
        parameters.shadowPath = UIBezierPath(roundedRect: cell.paper.bounds.insetBy(dx: 6, dy: 6), cornerRadius: 4)
        return UITargetedPreview(view: cell.paper, parameters: parameters)
    }
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, highlightPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? { documentPreview(indexPath) }
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfiguration configuration: UIContextMenuConfiguration, dismissalPreviewForItemAt indexPath: IndexPath) -> UITargetedPreview? { documentPreview(indexPath) }
    override func collectionView(_ collectionView: UICollectionView, willDisplayContextMenu configuration: UIContextMenuConfiguration, animator: (any UIContextMenuInteractionAnimating)?) { menuOpen = true }
    override func collectionView(_ collectionView: UICollectionView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: (any UIContextMenuInteractionAnimating)?) {
        let complete = { [weak self] in
            guard let self else { return }
            self.menuOpen = false
            if self.needsReload { self.needsReload = false; self.displayedItems = self.owner.items; self.collectionView.reloadData() }
        }
        if let animator { animator.addCompletion(complete) } else { complete() }
    }
    override func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: any UIContextMenuInteractionCommitAnimating) {
        guard let id = configuration.identifier as? String, let item = owner.items.first(where: { $0.id.uuidString == id }) else { return }
        animator.addCompletion { [weak self] in self?.owner.activate(item) }
    }
}

private final class DownloadDocumentCell: UICollectionViewCell {
    let paper = UIImageView()
    private let filename = UILabel()
    private let progress = UIProgressView(progressViewStyle: .default)
    private var task: Task<Void, Never>?
    private var representedID: UUID?
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear; contentView.backgroundColor = .clear
        paper.contentMode = .scaleAspectFit; paper.backgroundColor = .secondarySystemGroupedBackground
        paper.layer.cornerRadius = 4; paper.layer.masksToBounds = true
        paper.layer.borderWidth = 0.5; paper.layer.borderColor = UIColor.separator.cgColor
        filename.font = .preferredFont(forTextStyle: .caption1); filename.adjustsFontForContentSizeCategory = true
        filename.numberOfLines = 2; filename.textAlignment = .center; filename.textColor = .label
        for v in [paper, filename, progress] { v.translatesAutoresizingMaskIntoConstraints = false; contentView.addSubview(v) }
        NSLayoutConstraint.activate([
            paper.topAnchor.constraint(equalTo: contentView.topAnchor), paper.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            paper.widthAnchor.constraint(equalToConstant: 72), paper.heightAnchor.constraint(equalToConstant: 88),
            filename.topAnchor.constraint(equalTo: paper.bottomAnchor, constant: 10), filename.leadingAnchor.constraint(equalTo: contentView.leadingAnchor), filename.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            progress.topAnchor.constraint(equalTo: filename.bottomAnchor, constant: 6), progress.centerXAnchor.constraint(equalTo: paper.centerXAnchor), progress.widthAnchor.constraint(equalTo: paper.widthAnchor)
        ])
        isAccessibilityElement = true; accessibilityTraits = .button
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func prepareForReuse() { super.prepareForReuse(); task?.cancel(); representedID = nil; paper.image = nil }
    func configure(_ item: DownloadItem, url: URL?) {
        task?.cancel(); representedID = item.id
        filename.text = item.filename; accessibilityLabel = item.filename
        accessibilityValue = item.state == .downloading ? L10n.format("下载中 %@%", String(Int(item.progress * 100))) : ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file)
        progress.isHidden = item.state != .downloading; progress.progress = Float(item.progress)
        paper.image = UIImage(systemName: "doc.text"); paper.tintColor = UIColor(Theme.accent)
        guard let url, url.pathExtension.lowercased() == "pdf" else { return }
        task = Task { [weak self] in
            let data = await Task.detached(priority: .utility) {
                var data: Data?; var error: NSError?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { file in
                    data = PDFDocument(url: file)?.page(at: 0)?.thumbnail(of: CGSize(width: 144, height: 176), for: .cropBox).pngData()
                }
                return data
            }.value
            guard !Task.isCancelled, self?.representedID == item.id, let data, let image = UIImage(data: data) else { return }
            self?.paper.image = image
        }
    }
}
