import Cocoa

@MainActor
public class NCPanelTabBarItem: NSCollectionViewItem {
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

    private lazy var closeButton: NSButton = {
        let btn = NSButton(title: "X", target: self, action: #selector(closeTapped))
        btn.bezelStyle = .inline
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setContentHuggingPriority(.required, for: .horizontal)
        return btn
    }()

    public override func loadView() {
        self.view = NSView()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        view.addSubview(titleField)
        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 6),
            closeButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            titleField.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 6),
            titleField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            titleField.topAnchor.constraint(equalTo: view.topAnchor, constant: 4),
            titleField.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -4),
        ])
    }

    @objc public func configure(with title: String) {
        titleField.stringValue = title
    }

    @objc private func closeTapped() {
        guard let tabViewItem = tabViewItem, let tabBarView = tabBarView else { return }
        tabBarView.removeTabViewItem(tabViewItem)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        labelObservation?.invalidate()
        labelObservation = nil
        tabViewItem = nil
        titleField.stringValue = ""
    }
}

@objc
public protocol NCPanelTabBarViewDelegate: NSTabViewDelegate {
    // Extend with NCPanelTabBarView-specific delegate methods if needed
}

class NCPanelTabBarViewHiddenScroller: NSScroller {
    // let NSScroller tell NSScrollView that its own width is 0, so that it will not really occupy the drawing area.
    override class func scrollerWidth(for controlSize: ControlSize, scrollerStyle: Style) -> CGFloat {
        0
    }
}

private let SeparatorDecorationKind = NSCollectionView.DecorationElementKind("SeparatorDecorationKind")

private final class SeparatorDecorationView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.cgColor
        isHidden = false
        translatesAutoresizingMaskIntoConstraints = false
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.cgColor
        isHidden = false
        translatesAutoresizingMaskIntoConstraints = false
    }
}

private final class SeparatorFlowLayout: NSCollectionViewFlowLayout {
    private let separatorWidth: CGFloat = 1.0
    var minimumItemWidth: CGFloat = 120

    override func prepare() {
        super.prepare()
        // Ensure decoration is registered
        self.register(SeparatorDecorationView.self, forDecorationViewOfKind: SeparatorDecorationKind)

        guard let collectionView = self.collectionView else { return }

        // Compute available width inside the collection view's visible bounds
        let boundsWidth = collectionView.enclosingScrollView?.contentView.bounds.width ?? collectionView.bounds.width
        let sections = collectionView.numberOfSections
        guard sections > 0 else { return }
        let items = collectionView.numberOfItems(inSection: 0)
        guard items > 0 else { return }

        // Total spacing between items is (items - 1) * minimumInteritemSpacing
        let totalSpacing = CGFloat(max(items - 1, 0)) * self.minimumInteritemSpacing
        let totalInsets = self.sectionInset.left + self.sectionInset.right
        let available = max(0, boundsWidth - totalSpacing - totalInsets)

        // Target width per item
        let target = available / CGFloat(items)
        let width = max(minimumItemWidth, target)

        // Set computed size (height remains whatever is configured)
        self.itemSize = NSSize(width: width, height: self.itemSize.height)
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        var attributes = super.layoutAttributesForElements(in: rect)

        guard let collectionView = self.collectionView else { return attributes }
        let itemAttributes = attributes.filter({ $0.representedElementCategory == .item })

        // Add separators between items in the same section
        for attr in itemAttributes {
            guard let indexPath = attr.indexPath else { continue }

            // Don't add a separator after the last item in section
            let itemsInSection = collectionView.numberOfItems(inSection: indexPath.section)
            if indexPath.item >= itemsInSection - 1 { continue }

            if let separatorAttr = layoutAttributesForDecorationView(ofKind: SeparatorDecorationKind, at: indexPath) {
                attributes.append(separatorAttr)
            }
        }
        return attributes
    }

    override func layoutAttributesForDecorationView(
        ofKind elementKind: NSCollectionView.DecorationElementKind,
        at indexPath: IndexPath
    ) -> NSCollectionViewLayoutAttributes? {
        guard elementKind == SeparatorDecorationKind,
            let itemAttrs = super.layoutAttributesForItem(at: indexPath)
        else { return nil }

        let attrs = NSCollectionViewLayoutAttributes(forDecorationViewOfKind: elementKind, with: indexPath)
        var frame = itemAttrs.frame
        frame.origin.x = frame.maxX  // Place separator at the trailing edge of the item
        frame.size.width = separatorWidth
        attrs.frame = frame
        return attrs
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        return true
    }
}

@objc
public class NCPanelTabBarView: NSView, NSTabViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate {
    // MARK: - Delegate
    @objc public weak var delegate: NCPanelTabBarViewDelegate?

    // MARK: - Tab View Reference
    @objc public var tabView: NSTabView?

    // MARK: - Collection View
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
        flowLayout.minimumInteritemSpacing = 1
        flowLayout.minimumLineSpacing = 0
        flowLayout.itemSize = NSSize(width: 120, height: 28)
        flowLayout.minimumItemWidth = 120
        flowLayout.sectionInset = .init(top: 0, left: 0, bottom: 0, right: 0)
        collectionView.collectionViewLayout = flowLayout

        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.backgroundColors = [.clear]

        collectionView.register(
            NCPanelTabBarItem.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("NCPanelTabBarItem")
        )

        // Embed in scroll view
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.horizontalScroller = NCPanelTabBarViewHiddenScroller()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
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
        // Select current selected tab if available
        if let tabView = tabView, tabView.numberOfTabViewItems > 0 {
            let selectedIndex = tabView.indexOfTabViewItem(tabView.selectedTabViewItem ?? NSTabViewItem())
            if selectedIndex != NSNotFound {
                collectionView.selectItems(
                    at: [IndexPath(item: selectedIndex, section: 0)],
                    scrollPosition: .centeredHorizontally
                )
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
        tabView?.selectTabViewItem(item)
    }

    @objc public func removeTabViewItem(_ item: NSTabViewItem) {
        guard let tabView else { return }
        tabView.removeTabViewItem(item)
        self.tabViewDidChangeNumberOfTabViewItems(tabView)
    }

    // MARK: - NSTabViewDelegate
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

    // MARK: - NSCollectionViewDataSource
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

    // MARK: - NSCollectionViewDelegate
    public func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        guard let idx = indexPaths.first?.item, let tabView = tabView, idx < tabView.numberOfTabViewItems else {
            return
        }
        tabView.selectTabViewItem(at: idx)
    }

}
