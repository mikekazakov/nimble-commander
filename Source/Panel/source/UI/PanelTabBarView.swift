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

@objc
public class NCPanelTabBarView: NSView, NSTabViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate {
    // MARK: - Delegate
    @objc public weak var delegate: NCPanelTabBarViewDelegate?
    
    // MARK: - Tab View Reference
    @objc public var tabView: NSTabView?
    
    // MARK: - Collection View
    private let collectionView: NSCollectionView = NSCollectionView()
    private let scrollView: NSScrollView = NSScrollView()
    private let flowLayout: NSCollectionViewFlowLayout = NSCollectionViewFlowLayout()
    
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
        
        // Configure layout for horizontal scrolling
        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = 8
        flowLayout.minimumLineSpacing = 8
        flowLayout.itemSize = NSSize(width: 120, height: 28)
        
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
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = false
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
