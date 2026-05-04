import Cocoa

let NCPanelTabBarDraggingUTI = NSPasteboard.PasteboardType("com.magnumbytes.nimblecommander.NCPanelTabBarDraggingUTI")

@objc
public protocol NCPanelTabBarViewDelegate: NSTabViewDelegate {
    @objc optional func tabView(_ tabView: NSTabView, didCloseTabViewItem tabViewItem: NSTabViewItem)
    @objc optional func tabView(_ tabView: NSTabView, didDropTabViewItem tabViewItem: NSTabViewItem, inTabBarView tabBarView: NCPanelTabBarView)
    @objc optional func tabView(_ tabView: NSTabView, menuForTabViewItem tabViewItem: NSTabViewItem) -> NSMenu?
}

@MainActor
public class NCPanelTabBarItem: NSCollectionViewItem {
    // Colors
    public var selectedBackgroundColor: NSColor = NSColor.controlAccentColor.withAlphaComponent(0.25)
    public var hoverBackgroundColor: NSColor = NSColor.separatorColor.withAlphaComponent(0.2)
    public var defaultBackgroundColor: NSColor = NSColor.clear
    public var inactiveBackgroundColor: NSColor = NSColor.windowBackgroundColor.withAlphaComponent(0.1)
    
    private var isHovered: Bool = false
    private var trackingArea: NSTrackingArea?
    
    // TODO: debug stuff, remove this
    private let leftEdgeLine: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.systemBlue.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private let rightEdgeLine: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.systemRed.cgColor
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let titleField: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        tf.lineBreakMode = .byTruncatingMiddle
        tf.alignment = .center
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    @objc public weak var tabBarView: NCPanelTabBarView?
    private var labelObservation: NSKeyValueObservation?
    
    @objc public weak var tabViewItem: NSTabViewItem? {
        didSet {
            // Stop observing old
            labelObservation?.invalidate()
            labelObservation = nil
            
            // Update current title immediately
            if let title = tabViewItem?.label {
                titleField.stringValue = title
            }
            
            // Observe label changes on the new item
            if let item = tabViewItem {
                labelObservation = item.observe(\NSTabViewItem.label, options: [.initial, .new]) {
                    [weak self] _, change in
                    guard let self = self else { return }
                    if let newTitle = change.newValue {
                        Task { @MainActor in
                            self.titleField.stringValue = newTitle
                        }
                    }
                }
            }
        }
    }
    
    public let closeButton: NSButton = {
        let button = NSButton()
        button.action = #selector(closeTapped)
        button.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "")?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 10, weight: .regular))
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.setButtonType(.momentaryChange)
        button.bezelStyle = .circular
        button.isBordered = true
        button.isHidden = true
        button.showsBorderOnlyWhileMouseInside = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()
    
    public override func loadView() {
        self.view = NSView()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.layer?.backgroundColor = defaultBackgroundColor.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        closeButton.target = self
        view.addSubview(titleField)
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
            closeButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 16),
            closeButton.heightAnchor.constraint(equalToConstant: 16),
            titleField.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 4),
            titleField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            titleField.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            titleField.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])
        
        view.addSubview(leftEdgeLine)
        view.addSubview(rightEdgeLine)
        NSLayoutConstraint.activate([
            leftEdgeLine.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            leftEdgeLine.topAnchor.constraint(equalTo: view.topAnchor),
            leftEdgeLine.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            leftEdgeLine.widthAnchor.constraint(equalToConstant: 1),
            
            rightEdgeLine.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rightEdgeLine.topAnchor.constraint(equalTo: view.topAnchor),
            rightEdgeLine.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rightEdgeLine.widthAnchor.constraint(equalToConstant: 1),
        ])
    }
    
    public override func viewDidLayout() {
        super.viewDidLayout()
        updateTrackingArea()
    }
    
    public override var isSelected: Bool {
        didSet { updateBackground() }
    }
    
    private func updateTrackingArea() {
        if let trackingArea = trackingArea {
            view.removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways, .inVisibleRect]
        let ta = NSTrackingArea(rect: view.bounds, options: options, owner: self, userInfo: nil)
        view.addTrackingArea(ta)
        trackingArea = ta
    }
    
    public override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateBackground()
        
        if let tabViewItem = tabViewItem, let tabBarView = tabBarView,
           tabBarView.tabBarItemShouldShowCloseButton(tabViewItem) {
            self.closeButton.isHidden = false
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateBackground()
        self.closeButton.isHidden = true
    }
    
    public override func viewWillAppear() {
        super.viewWillAppear()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowBecameKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: view.window
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowResignedKey(_:)),
            name: NSWindow.didResignKeyNotification,
            object: view.window
        )
        updateBackground()
    }
    
    public override func viewWillDisappear() {
        super.viewWillDisappear()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didBecomeKeyNotification, object: view.window)
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: view.window)
    }
    
    @objc private func windowBecameKey(_ note: Notification) { updateBackground() }
    @objc private func windowResignedKey(_ note: Notification) { updateBackground() }
    
    private func updateBackground() {
        guard let window = view.window else {
            view.layer?.backgroundColor = defaultBackgroundColor.cgColor
            return
        }
        if !window.isKeyWindow {
            view.layer?.backgroundColor = inactiveBackgroundColor.cgColor
            return
        }
        if isSelected {
            view.layer?.backgroundColor = selectedBackgroundColor.cgColor
        } else if isHovered {
            view.layer?.backgroundColor = hoverBackgroundColor.cgColor
        } else {
            view.layer?.backgroundColor = defaultBackgroundColor.cgColor
        }
    }
    
    @objc public func configure(with title: String) {
        titleField.stringValue = title
    }
    
    @objc private func closeTapped() {
        guard let tabViewItem = tabViewItem, let tabBarView = tabBarView else { return }
        tabBarView.tabBarItemCloseButtonClicked(tabViewItem)
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        labelObservation?.invalidate()
        labelObservation = nil
        tabViewItem = nil
        titleField.stringValue = ""
        isHovered = false
        updateBackground()
        self.closeButton.isHidden = true
        if let trackingArea = trackingArea {
            view.removeTrackingArea(trackingArea)
        }
    }
    
    public override var draggingImageComponents: [NSDraggingImageComponent] {
        // TODO: build a real image representation of the collection item for dragging
        let img = NSImage(systemSymbolName: "table.furniture.fill", accessibilityDescription: "")!
        img.size = NSSize(width: 32, height: 32)
        let comp = NSDraggingImageComponent(key: .icon)
        comp.contents = img
        comp.frame = NSRect(origin: .zero, size: img.size)
        return [comp]
    }
}

private class NCPanelTabBarCollectionView: NSCollectionView {
    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        if let tabBarView = delegate as? NCPanelTabBarView {
            tabBarView.collectionView(self, draggingExited: sender)
        }
        super.draggingExited(sender)
    }
}

class NCPanelTabBarViewHiddenScroller: NSScroller {
    // let NSScroller tell NSScrollView that its own width is 0, so that it will not really occupy the drawing area.
    override class func scrollerWidth(for controlSize: ControlSize, scrollerStyle: Style) -> CGFloat {
        0
    }
}

private final class SeparatorFlowLayout: NSCollectionViewFlowLayout {
    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        return true
    }
    
    override func invalidationContext(forBoundsChange newBounds: NSRect) -> NSCollectionViewLayoutInvalidationContext {
        let context = super.invalidationContext(forBoundsChange: newBounds) as! NSCollectionViewFlowLayoutInvalidationContext
        context.invalidateFlowLayoutDelegateMetrics = true
        context.invalidateFlowLayoutAttributes = true
        return context
    }
}

@objc
public class NCPanelTabBarDraggingItem: NSPasteboardItem {
    /// Index of the item inside the source collection view that's being dragged
    @objc public let sourceIndexPath: IndexPath
    
    /// The tab view item being dragged
    @objc public let tabViewItem: NSTabViewItem
    
    @objc public init(sourceIndexPath: IndexPath, tabViewItem: NSTabViewItem) {
        self.sourceIndexPath = sourceIndexPath
        self.tabViewItem = tabViewItem
        super.init()
        super.setString("", forType: NCPanelTabBarDraggingUTI)
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
}

@objc
public class NCPanelTabBarView: NSView,
                                NSTabViewDelegate,
                                NSCollectionViewDelegate,
                                NSCollectionViewDelegateFlowLayout
{
    @objc public weak var delegate: NCPanelTabBarViewDelegate?
    
    @objc public var tabView: NSTabView?
    
    private let collectionView: NCPanelTabBarCollectionView = NCPanelTabBarCollectionView()
    private let scrollView: NSScrollView = NSScrollView()
    private let flowLayout: SeparatorFlowLayout = SeparatorFlowLayout()
    private var dataSource: NSCollectionViewDiffableDataSource<Int, NSTabViewItem>!
    
    /// When true, tabViewDidChangeNumberOfTabViewItems won't trigger a reload.
    private var suppressCollectionViewReload = false
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupCollectionView()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCollectionView()
    }
    
    private func setupCollectionView() {
        wantsLayer = true
        
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 0
        flowLayout.itemSize = NSSize(width: 120, height: 25)
        flowLayout.sectionInset = .init(top: 0, left: 0, bottom: 0, right: 0)
        
        collectionView.collectionViewLayout = flowLayout
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.register(
            NCPanelTabBarItem.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("NCPanelTabBarItem")
        )
        collectionView.registerForDraggedTypes([NCPanelTabBarDraggingUTI])
        collectionView.setDraggingSourceOperationMask(.move, forLocal: true)
        collectionView.setDraggingSourceOperationMask([], forLocal: false)
        collectionView.autoresizingMask = [.width, .height]
        
        // Build the diffable data source.  The closure is the sole place that
        // dequeues and configures NCPanelTabBarItem cells.
        let identifier = NSUserInterfaceItemIdentifier("NCPanelTabBarItem")
        dataSource = NSCollectionViewDiffableDataSource<Int, NSTabViewItem>(collectionView: collectionView) { [weak self] cv, indexPath, tabViewItem in
            guard let self else { return NSCollectionViewItem() }
            let cell = cv.makeItem(withIdentifier: identifier, for: indexPath)
            if let barItem = cell as? NCPanelTabBarItem {
                barItem.configure(with: tabViewItem.label)
                barItem.tabViewItem = tabViewItem
                barItem.tabBarView = self
            }
            return cell
        }
        
        // Embed in scroll view
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScroller = NCPanelTabBarViewHiddenScroller()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.borderType = .noBorder
        scrollView.documentView = collectionView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(scrollView)
        
        // Pin scroll view to edges
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
    
    /// Reload when tabView changes
    @objc public func reloadTabs() {
        rebuildCollectionViewFromTabView()
        collectionView.collectionViewLayout?.invalidateLayout()
        syncSelectionToCollectionView()
    }
    
    /// Fill the collection with the tabs of the underlying TabView
    private func rebuildCollectionViewFromTabView() {
        guard let tabView else { return }
        var snapshot = NSDiffableDataSourceSnapshot<Int, NSTabViewItem>()
        snapshot.appendSections([0])
        snapshot.appendItems(tabView.tabViewItems)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
    
    private func syncSelectionToCollectionView() {
        guard let tabView = tabView,
              let selected = tabView.selectedTabViewItem,
              let indexPath = dataSource.indexPath(for: selected) else { return }
        collectionView.selectionIndexPaths = [indexPath]
        collectionView.scrollToItems(at: [indexPath], scrollPosition: .nearestVerticalEdge)
    }
    
    @objc public func numberOfTabViewItems() -> Int {
        return tabView?.numberOfTabViewItems ?? 0
    }
    
    @objc public func indexOfTabViewItem(_ item: NSTabViewItem) -> Int {
        return tabView?.indexOfTabViewItem(item) ?? NSNotFound
    }
    
    @objc public func selectedTabViewItem() -> NSTabViewItem? {
        return tabView?.selectedTabViewItem
    }
    
    @objc public func selectTabViewItem(_ item: NSTabViewItem) {
        if let tab_index = tabView?.indexOfTabViewItem(item), tab_index != NSNotFound {
            tabView?.selectTabViewItem(item)
            syncSelectionToCollectionView()
        }
    }
    
    @objc public func removeTabViewItem(_ item: NSTabViewItem) {
        guard let tabView else { return }
        tabView.removeTabViewItem(item)
        self.tabViewDidChangeNumberOfTabViewItems(tabView)
    }
    
    public func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool {
        // Forward to delegate if implemented; default to true
        if let delegate = delegate, delegate.responds(to: #selector(NSTabViewDelegate.tabView(_:shouldSelect:))) {
            return delegate.tabView?(tabView, shouldSelect: tabViewItem) ?? true
        }
        return true
    }
    
    public func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
        // Forward to delegate if implemented
        if let delegate = delegate, delegate.responds(to: #selector(NSTabViewDelegate.tabView(_:willSelect:))) {
            delegate.tabView?(tabView, willSelect: tabViewItem)
        }
    }
    
    public func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        // Forward to delegate if implemented
        if let delegate = delegate, delegate.responds(to: #selector(NSTabViewDelegate.tabView(_:didSelect:))) {
            delegate.tabView?(tabView, didSelect: tabViewItem)
        }
        syncSelectionToCollectionView()
    }
    
    public func tabViewDidChangeNumberOfTabViewItems(_ tabView: NSTabView) {
        if let delegate = delegate,
           delegate.responds(to: #selector(NSTabViewDelegate.tabViewDidChangeNumberOfTabViewItems(_:)))
        {
            delegate.tabViewDidChangeNumberOfTabViewItems?(tabView)
        }
        guard !suppressCollectionViewReload else { return }
        reloadTabs()
    }
    
    public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let indexPath = indexPaths.first,
              let tabViewItem = dataSource.itemIdentifier(for: indexPath) else { return }
        tabView?.selectTabViewItem(tabViewItem)
    }
    
    public func collectionView(
        _ collectionView: NSCollectionView,
        layout collectionViewLayout: NSCollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> NSSize {
        let boundsWidth = scrollView.bounds.width
        let items: Int = collectionView.numberOfItems(inSection: 0)
        let available: Int = Int(boundsWidth.rounded())
        let integerWidth : Int = available
        let baseWidth : Int = integerWidth / items
        let remainder : Int = integerWidth % items
        let itemWidth : Int = baseWidth + (indexPath.item < remainder ? 1 : 0)
        let baseItemSize: NSSize = flowLayout.itemSize
        if( itemWidth < Int(baseItemSize.width)) {
            return baseItemSize
        }
        else {
            return NSSize(width: CGFloat(itemWidth), height: baseItemSize.height)
        }
    }
    
    public func collectionView(_ collectionView: NSCollectionView, canDragItemsAt indexPaths: Set<IndexPath>, with event: NSEvent) -> Bool {
        // Only allow dragging if there's more than one tab, since we can't leave the panel empty
        return collectionView.numberOfItems(inSection: 0) > 1
    }
    
    public func collectionView(_ collectionView: NSCollectionView,
                               pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        guard let tabViewItem = dataSource.itemIdentifier(for: indexPath) else { return nil }
        let item = NCPanelTabBarDraggingItem(sourceIndexPath: indexPath, tabViewItem: tabViewItem)
        return item
    }
    
    public func collectionView(_ collectionView: NSCollectionView,
                               validateDrop draggingInfo: any NSDraggingInfo,
                               proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                               dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        guard let pasteboardItem: NCPanelTabBarDraggingItem = draggingItem(from: draggingInfo.draggingPasteboard) else { return [] }
        let draggedItem: NSTabViewItem = pasteboardItem.tabViewItem
        
        // The drop operation should use the index where the item is placed, not before it
        proposedDropOperation.pointee = .on
        
        // The collection of tabs in this collection prior to any transformations (possibly including the phantom one)
        let snapshotItems: [NSTabViewItem] = dataSource.snapshot().itemIdentifiers(inSection: 0)
        
        // Whether the dragged item is already inserted into this collection view
        let itemPresent: Bool = snapshotItems.contains(draggedItem)
        
        // The number of item this collection should have, including a phantom slot
        let targetSlotCount: Int = snapshotItems.count + (itemPresent ? 0 : 1)
        assert(targetSlotCount > 0)
        
        // Index where the dragged item should be in this collection
        let targetVisualIndex = computeTargetSlot(for: draggingInfo, slotCount: targetSlotCount)
        
        // Current index of the dragged item inside this collection, if any
        let currentIdx: Int = itemPresent ? snapshotItems.firstIndex(of: draggedItem)! : -1
        if targetVisualIndex != currentIdx {
            // Need to adjust this collection to reflect the changed drag position
            var snapshot = dataSource.snapshot()
            if itemPresent {
                snapshot.deleteItems([draggedItem])
            }
            let remaining : [NSTabViewItem] = snapshot.itemIdentifiers(inSection: 0)
            if targetVisualIndex < remaining.count {
                snapshot.insertItems([draggedItem], beforeItem: remaining[targetVisualIndex])
            } else {
                snapshot.appendItems([draggedItem], toSection: 0)
            }
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        // Update the proposed drop index to reflect the visual index where we predict the item should fall
        if  proposedDropIndexPath.pointee.item != targetVisualIndex  {
            proposedDropIndexPath.pointee = NSIndexPath(forItem: targetVisualIndex, inSection: 0)
        }
        
        return .move
    }
    
    public func collectionView(_ collectionView: NSCollectionView,
                               acceptDrop draggingInfo: any NSDraggingInfo,
                               indexPath: IndexPath,
                               dropOperation: NSCollectionView.DropOperation) -> Bool {
        guard let sourceBar : NCPanelTabBarView = (draggingInfo.draggingSource as? NSCollectionView)?.delegate as? NCPanelTabBarView,
              let pasteboardItem : NCPanelTabBarDraggingItem = draggingItem(from: draggingInfo.draggingPasteboard),
              let tabView else { return false }
        let draggedItem: NSTabViewItem = pasteboardItem.tabViewItem
        
        // Did we drop into ourselves?
        let isSameInstance = (sourceBar === self)
        let snapshotItems   = dataSource.snapshot().itemIdentifiers(inSection: 0)
        assert(snapshotItems.contains(draggedItem), "Dragged item not found in the snapshot")
        
        if isSameInstance {
            // Reorder within the same NSTabView.
            // For simplicity, dump the entire snapshot back into NSTabView (that's suboptimal)
            suppressCollectionViewReload = true
            tabView.tabViewItems = snapshotItems
            suppressCollectionViewReload = false
        } else {
            // Cross-instance: move draggedItem from source's NSTabView into ours.
            guard let sourceTabView : NSTabView = sourceBar.tabView else { return false }
            
            // Remove the source item from the source NSTabView instance and force-reload the connected NCPanelTabBarView
            sourceBar.suppressCollectionViewReload = true
            sourceTabView.removeTabViewItem(draggedItem)
            sourceBar.suppressCollectionViewReload = false
            sourceBar.reloadTabs()

            // Update our underlying NSTabView by inserting the new tab
            let insertionIdx : Int = snapshotItems.firstIndex(of: draggedItem)!
            suppressCollectionViewReload = true
            tabView.insertTabViewItem(draggedItem, at: insertionIdx)
            suppressCollectionViewReload = false
        }
        
        syncSelectionToCollectionView()
        
        if let delegate,
           delegate.responds(to: #selector(NCPanelTabBarViewDelegate.tabView(_:didDropTabViewItem:inTabBarView:))) {
            delegate.tabView?(tabView, didDropTabViewItem: draggedItem, inTabBarView: self)
        }
        return true
    }
    
    public func collectionView(_ collectionView: NSCollectionView,
                               draggingSession session: NSDraggingSession,
                               willBeginAt screenPoint: NSPoint,
                               forItemsAt indexPaths: Set<IndexPath>) {
        // If the drag is ended without a drop - immediately revert the UI to the original state
        session.animatesToStartingPositionsOnCancelOrFail = false
    }
    
    public func collectionView(_ collectionView: NSCollectionView,
                               draggingSession session: NSDraggingSession,
                               endedAt screenPoint: NSPoint,
                               dragOperation operation: NSDragOperation) {
        // Successful drops are fully committed in acceptDrop; only cancellations need cleanup.
        guard operation == [] else { return }
        rebuildCollectionViewFromTabView()
    }
    
    fileprivate func collectionView(_ collectionView: NSCollectionView,
                                    draggingExited session: (any NSDraggingInfo)?) {
        // Whenever a drag leaves this collection view, we need to remove the temporary placed item from it
        guard let session = session,
              let draggedItem = self.draggingItem(from: session.draggingPasteboard) else { return }
        let draggedTabView : NSTabViewItem = draggedItem.tabViewItem
        var snapshot = dataSource.snapshot()
        guard snapshot.itemIdentifiers(inSection: 0).contains(draggedTabView) else { return }
        snapshot.deleteItems([draggedTabView])
        dataSource.apply(snapshot, animatingDifferences: true)
    }
            
    /// Retrieves the live NCPanelTabBarDraggingItem from a pasteboard (local drags preserve identity).
    private func draggingItem(from pasteboard: NSPasteboard) -> NCPanelTabBarDraggingItem? {
        guard let items = pasteboard.pasteboardItems else { return nil }
        return items.first as? NCPanelTabBarDraggingItem
    }
        
    /// Converts the drag cursor position to a slot index in [0, slotCount).
    /// Snaps to the nearest inter-item gap: left half of an item → insert before it,
    /// right half → insert after it.
    private func computeTargetSlot(for draggingInfo: NSDraggingInfo, slotCount: Int) -> Int {
        // TODO: optimize this
        let inView : NSPoint = collectionView.convert(draggingInfo.draggingLocation, from: nil)
        let itemCount : Int = collectionView.numberOfItems(inSection: 0)
        // Walk visible layout attributes to find which item the cursor is over.
        if let layout : NSCollectionViewLayout = collectionView.collectionViewLayout {
            for i in 0..<itemCount {
                let ip = IndexPath(item: i, section: 0)
                if let attrs = layout.layoutAttributesForItem(at: ip) {
                    if attrs.frame.contains(inView) {
                        // Left half → before this item; right half → after it.
                        let midX = attrs.frame.midX
                        return inView.x < midX ? i : i + 1
                    }
                }
            }
        }
        
        // Cursor is outside all items — clamp to nearest end.
        let itemWidth = collectionView.bounds.width / CGFloat(max(itemCount, 1))
        return max(0, min(Int((inView.x / max(itemWidth, 1)).rounded()), slotCount))
    }
    
    fileprivate func tabBarItemCloseButtonClicked(_ tabViewItem: NSTabViewItem) {
        guard let tabView else { return }
        
        // TODO: add shouldClose / willClose?
        
        removeTabViewItem(tabViewItem)
        
        if let delegate = delegate, delegate.responds(to: #selector(NCPanelTabBarViewDelegate.tabView(_:didCloseTabViewItem:))) {
            delegate.tabView?(tabView, didCloseTabViewItem: tabViewItem)
        }
    }
    
    fileprivate func tabBarItemShouldShowCloseButton(_ tabViewItem: NSTabViewItem) -> Bool {
        return collectionView.numberOfItems(inSection: 0) > 1
    }
    
    @objc public func closeButtonOfTabViewItem(_ item: NSTabViewItem) -> NSButton? {
        guard let indexPath = dataSource.indexPath(for: item),
              let tabBarItem = collectionView.item(at: indexPath) as? NCPanelTabBarItem else {
            return nil
        }
        return tabBarItem.closeButton
    }
    
    @objc public override func menu(for event: NSEvent) -> NSMenu? {
        guard let tabView else { return super.menu(for: event) }

        let localPosition : NSPoint = convert(event.locationInWindow, from: nil)
        
        // If the menu request lands into the collection view - try to delegate it to the client
        if scrollView.frame.contains(localPosition) {
            let collectionViewPosition : NSPoint = collectionView.convert(localPosition, from: self)
            if let indexPath = collectionView.indexPathForItem(at: collectionViewPosition), indexPath.last != nil {
                let item : NSTabViewItem = tabView.tabViewItem(at: indexPath.last!)
                if let delegate = delegate, delegate.responds(to: #selector(NCPanelTabBarViewDelegate.tabView(_:menuForTabViewItem:))) {
                    return delegate.tabView?(tabView, menuForTabViewItem: item)
                }
            }
        }
        
        return super.menu(for: event)
    }
}
