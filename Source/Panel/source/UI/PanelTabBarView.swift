import Cocoa

let NCPanelTabBarDraggingUTI = NSPasteboard.PasteboardType("com.magnumbytes.nimblecommander.NCPanelTabBarDraggingUTI")

@objc
public protocol NCPanelTabBarViewDelegate: NSTabViewDelegate {
    @objc optional func tabView(_ tabView: NSTabView, didCloseTabViewItem tabViewItem: NSTabViewItem)
    @objc optional func tabView(_ tabView: NSTabView, didDropTabViewItem tabViewItem: NSTabViewItem, inTabBarView tabBarView: NCPanelTabBarView)
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
    @objc public let sourceIndexPath: IndexPath
    @objc public init(sourceIndexPath: IndexPath) {
        self.sourceIndexPath = sourceIndexPath
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
                                NSCollectionViewDataSource,
                                NSCollectionViewDelegate,
                                NSCollectionViewDelegateFlowLayout
{
    @objc public weak var delegate: NCPanelTabBarViewDelegate?
    
    @objc public var tabView: NSTabView?
    
    private let collectionView: NSCollectionView = NSCollectionView()
    private let scrollView: NSScrollView = NSScrollView()
    private let flowLayout: SeparatorFlowLayout = SeparatorFlowLayout()
    
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
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]
        collectionView.register(
            NCPanelTabBarItem.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("NCPanelTabBarItem")
        )
        collectionView.registerForDraggedTypes([NCPanelTabBarDraggingUTI])
        collectionView.setDraggingSourceOperationMask(NSDragOperation.move, forLocal: true)
        collectionView.setDraggingSourceOperationMask([], forLocal: false)
        collectionView.autoresizingMask = [.width, .height]
        
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
    
    // Reload when tabView changes
    @objc public func reloadTabs() {
        collectionView.reloadData()
        collectionView.collectionViewLayout?.invalidateLayout()
        syncSelectionToCollectionView()
    }
    
    private func syncSelectionToCollectionView() {
        if let tabView = tabView, tabView.numberOfTabViewItems > 0 {
            if let selectedTabView = tabView.selectedTabViewItem {
                let selectedIndex = tabView.indexOfTabViewItem(selectedTabView)
                if selectedIndex != NSNotFound {
                    collectionView.selectionIndexPaths = [IndexPath(item: selectedIndex, section: 0)]
                    collectionView.scrollToItems(at: [IndexPath(item: selectedIndex, section: 0)], scrollPosition: .nearestVerticalEdge)
                }
            }
        }
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
        // Forward to delegate if implemented
        if let delegate = delegate,
           delegate.responds(to: #selector(NSTabViewDelegate.tabViewDidChangeNumberOfTabViewItems(_:)))
        {
            delegate.tabViewDidChangeNumberOfTabViewItems?(tabView)
        }
        reloadTabs()
    }
    
    public func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }
    
    public func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabView?.numberOfTabViewItems ?? 0
    }
    
    public func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath)
    -> NSCollectionViewItem
    {
        let identifier = NSUserInterfaceItemIdentifier("NCPanelTabBarItem")
        let item = collectionView.makeItem(withIdentifier: identifier, for: indexPath)
        if let tabView = tabView, indexPath.item < tabView.numberOfTabViewItems,
           let tabItem = tabView.tabViewItem(at: indexPath.item) as NSTabViewItem?
        {
            let title = tabItem.label
            (item as? NCPanelTabBarItem)?.configure(with: title)
            (item as? NCPanelTabBarItem)?.tabViewItem = tabItem
            (item as? NCPanelTabBarItem)?.tabBarView = self
        }
        return item
    }
    
    public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let idx = indexPaths.first?.item, let tabView = tabView, idx < tabView.numberOfTabViewItems else {
            return
        }
        tabView.selectTabViewItem(at: idx)
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
        if collectionView.numberOfItems(inSection: 0) > 1 {
            return true
        }
        else {
            return false
        }
    }
    
    public func collectionView(_ collectionView: NSCollectionView,
                               pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        return NCPanelTabBarDraggingItem(sourceIndexPath: indexPath)
    }
    
    public func collectionView(_ collectionView: NSCollectionView,
                               validateDrop draggingInfo: any NSDraggingInfo,
                               proposedIndexPath proposedDropIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                               dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        NSLog("validateDrop: proposedIndex=\(proposedDropIndexPath.pointee), proposedDropOperation=\(proposedDropOperation.pointee)")
        var operation: NSDragOperation = []
                
        if let draggingSource = draggingInfo.draggingSource as? NSCollectionView, draggingSource == collectionView {
            // Only allow internal moves within the same collection view for now
            if( proposedDropOperation.pointee == .on ) {
                proposedDropOperation.pointee = .before
                proposedDropIndexPath.pointee = NSIndexPath(forItem: proposedDropIndexPath.pointee.item + 1, inSection: 0)
            }                        
            operation = [.move]
        }
        NSLog("validateDrop result: proposedIndex=\(proposedDropIndexPath.pointee), proposedDropOperation=\(proposedDropOperation.pointee), operation=\(operation)")
        return operation
    }
    
    public func collectionView(_ collectionView: NSCollectionView,
                               acceptDrop draggingInfo: any NSDraggingInfo,
                               indexPath: IndexPath,
                               dropOperation: NSCollectionView.DropOperation) -> Bool {
        NSLog("acceptDrop: indexPath=\(indexPath), dropOperation=\(dropOperation)")
        if let draggingSource = draggingInfo.draggingSource as? NSCollectionView, draggingSource != collectionView {
            return false // Only allow internal moves within the same collection view for now
        }
        
        draggingInfo.enumerateDraggingItems(for: collectionView,
                                            classes: [NCPanelTabBarDraggingItem.self]) { draggingItem, idx, stop in
            guard let draggingItem = draggingItem.item as? NCPanelTabBarDraggingItem else { return }
            let sourceIndexPath = draggingItem.sourceIndexPath
            let destinationIndexPath = indexPath
            NSLog("Moving item from \(sourceIndexPath) to \(destinationIndexPath)")
            if let tabView = self.tabView, sourceIndexPath.item < tabView.numberOfTabViewItems,
               destinationIndexPath.item < tabView.numberOfTabViewItems {
                let itemToMove = tabView.tabViewItem(at: sourceIndexPath.item)
                tabView.removeTabViewItem(itemToMove)
                if sourceIndexPath.item > destinationIndexPath.item {
                    tabView.insertTabViewItem(itemToMove, at: destinationIndexPath.item)
                }
                else {
                    tabView.insertTabViewItem(itemToMove, at: destinationIndexPath.item - 1)
                }
                self.reloadTabs()
                if let delegate = self.delegate, delegate.responds(to: #selector(NCPanelTabBarViewDelegate.tabView(_:didDropTabViewItem:inTabBarView:))) {
                    delegate.tabView?(tabView, didDropTabViewItem: itemToMove, inTabBarView: self)
                }
            }
        }   
        return true
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
        if collectionView.numberOfItems(inSection: 0) > 1 {
            return true
        }
        return false
    }
    
    @objc public func closeButtonOfTabViewItem(_ item: NSTabViewItem) -> NSButton? {
        guard let tabView else { return nil }
        let index = tabView.indexOfTabViewItem(item)
        if index == NSNotFound {
            return nil
        }
        
        if let tabBarItem = collectionView.item(at: IndexPath(item: index, section: 0)) as? NCPanelTabBarItem {
            return tabBarItem.closeButton
        }
        
        return nil
    }
}
