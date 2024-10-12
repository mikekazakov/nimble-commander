// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.

import Cocoa

@objc protocol PreferencesViewControllerProtocol
{
    @objc var identifier: String { get }
    @objc var toolbarItemImage: NSImage { get }
    @objc var toolbarItemLabel: String { get }
}

private typealias ViewController = NSViewController & PreferencesViewControllerProtocol

@objc class PreferencesWindowController: NSWindowController, NSToolbarDelegate
{
    fileprivate let controllers: [ViewController]
    fileprivate var selectedController: ViewController?
    let toolbar: NSToolbar = NSToolbar()
    var toolbarItems: [NSToolbarItem] = []
    
    @objc init( controllers: [NSViewController & PreferencesViewControllerProtocol], title: String ) {
        self.controllers = controllers
        
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 270),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: true)
        window.title = title
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
        self.shouldCascadeWindows = false
        
        toolbar.isVisible = true
        toolbar.displayMode = .iconAndLabel
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .preference
        }
        
        controllers.forEach {
            let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier($0.identifier) )
            item.image = $0.toolbarItemImage
            item.label = $0.toolbarItemLabel
            item.target = self
            item.action = #selector(selectToolbarItem(_:))
            toolbarItems.append(item)
        }
        
        toolbar.delegate = self
        window.toolbar = toolbar
        
        if !controllers.isEmpty {
            let first = controllers.first!
            resizeWindowForContentSize(first.view.bounds.size, duration: 0.0)
            makeActive(controller: first)
        }
        
        window.setFrameAutosaveName("PreferencesWindow")
        if !window.setFrameUsingName(window.frameAutosaveName) {
            window.center()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    {
        toolbarItems.map { $0.itemIdentifier }
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    {
        toolbarItems.map { $0.itemIdentifier }
    }
    
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    {
        toolbarItems.map { $0.itemIdentifier }
    }
    
    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem?
    {
        toolbarItems.first(where: { $0.itemIdentifier == itemIdentifier })
    }
    
    @objc func selectToolbarItem(_ item: NSToolbarItem) {
        guard let window = window else { return }
        guard let controller = controllers.first(where: { $0.identifier == item.itemIdentifier.rawValue }) else {
            return
        }
        
        if let selectedController {
            if selectedController == controller {
                return
            }
            selectedController.viewWillDisappear()
            selectedController.view.removeFromSuperview()
            window.contentView = nil
            selectedController.viewDidDisappear()
        }
        
        selectedController = controller
        
        let currentSize = window.contentRect(forFrameRect: window.frame).size
        let newSize = controller.view.bounds.size
        let diff = hypot(abs(currentSize.width - newSize.width), abs(currentSize.height - newSize.height))
        let duration = 0.01 + diff * 0.001
        resizeWindowForContentSize(controller.view.bounds.size, duration: duration)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.01) {
            if let selectedController = self.selectedController {
                if selectedController == controller {
                    self.makeActive(controller: controller)
                }
            }
        }
    }
    
    fileprivate func makeActive(controller: ViewController) {
        guard let window = window else { return }
        selectedController = controller
        controller.viewWillAppear()
        window.contentView = controller.view
        controller.viewDidAppear()
        window.title = controller.toolbarItemLabel
        window.toolbar!.selectedItemIdentifier = NSToolbarItem.Identifier(controller.identifier)
    }
    
    func resizeWindowForContentSize(_ size: NSSize, duration: Double) {
        guard let window = window else { return }
        
        let frame = window.contentRect(forFrameRect: window.frame)
        let newX = NSMinX(frame) + (0.5 * (NSWidth(frame) - size.width))
        let newFrame = window.frameRect(forContentRect: NSRect(x: newX, y: NSMaxY(frame) - size.height, width: size.width, height: size.height))
        
        if duration > 0.0 {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.duration = duration
            NSAnimationContext.current.allowsImplicitAnimation = true
            window.setFrame(newFrame, display: true)
            NSAnimationContext.endGrouping()
        }
        else {
            window.setFrame(newFrame, display: true)
        }
    }
}
