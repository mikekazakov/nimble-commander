// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#import <MMTabBarView/MMTabBarView.h>
#import <MMTabBarView/MMTabBarItem.h>
#include "FilePanelsTabbedHolder.h"
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include <NimbleCommander/States/FilePanels/PanelView.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include "TabBarStyle.h"
#include <Utility/ObjCpp.h>

@interface FilePanelsTabbedBarItem : NSObject <MMTabBarItem>

@property (atomic, assign) BOOL hasCloseButton;

@end

@implementation FilePanelsTabbedBarItem

- (id)init
{
    self = [super init];
    if(self) {
        self.hasCloseButton = true;
    }
    return self;
}

@end

@implementation FilePanelsTabbedHolder
{
    MMTabBarView    *m_TabBar;
    NSTabView       *m_TabView;
    bool m_TabBarShown;
}

- (id) initWithFrame:(NSRect)frameRect
{
    static std::once_flag once;
    std::call_once(once, []{
        [MMTabBarView registerTabStyleClass:TabBarStyle.class];
    });
    
    self = [super initWithFrame:frameRect];
    if(self) {
        m_TabBarShown = false;
        
        m_TabView = [[NSTabView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        m_TabView.translatesAutoresizingMaskIntoConstraints = NO;
        m_TabView.tabViewType = NSNoTabsNoBorder;
        [m_TabView addConstraint:[NSLayoutConstraint constraintWithItem:m_TabView
                                                              attribute:NSLayoutAttributeWidth
                                                              relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1.0
                                                               constant:50]];
        
        NSLayoutConstraint *c = [NSLayoutConstraint constraintWithItem:m_TabView
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1.0
                                                              constant:50];
        c.priority = NSLayoutPriorityDefaultLow;
        [m_TabView addConstraint:c];
        [self addSubview:m_TabView];
        
        m_TabBar = [[MMTabBarView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        m_TabBar.translatesAutoresizingMaskIntoConstraints = NO;
        m_TabBar.tabView = m_TabView;
        m_TabBar.showAddTabButton = true;
        m_TabBar.allowAddTabButtonMenu = true;
        m_TabBar.canCloseOnlyTab = false;
        m_TabBar.disableTabClose = false;
        m_TabBar.onlyShowCloseOnHover = true;
        m_TabBar.useOverflowMenu = false;
        m_TabBar.buttonMinWidth = 100;
        m_TabBar.buttonMaxWidth = 2000;
        m_TabBar.buttonOptimumWidth = 2000;
        [m_TabBar setStyleNamed:@"NC"];
        [m_TabBar addConstraint:[NSLayoutConstraint constraintWithItem:m_TabBar
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1.0
                                                              constant:50]];
        c = [NSLayoutConstraint constraintWithItem:m_TabBar
                                         attribute:NSLayoutAttributeHeight
                                         relatedBy:NSLayoutRelationEqual
                                            toItem:nil
                                         attribute:NSLayoutAttributeNotAnAttribute
                                        multiplier:1.0
                                          constant:m_TabBar.heightOfTabBarButtons];
        c.priority = NSLayoutPriorityDefaultLow+1;
        [m_TabBar addConstraint:c];
        m_TabView.delegate = m_TabBar;
        
        [self doLayoutTabless];
    }
    return self;
}

- (BOOL)isOpaque
{
    return true;
}

- (void) doLayoutTabless
{
    [self removeConstraints:self.constraints];
    NSDictionary *views = NSDictionaryOfVariableBindings(m_TabView);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_TabView]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_TabView]-(==0)-|" options:0 metrics:nil views:views]];
}

- (void) doLayoutWithTabs
{
    [self removeConstraints:self.constraints];
    NSDictionary *views = NSDictionaryOfVariableBindings(m_TabView, m_TabBar);
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_TabView]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"|-(0)-[m_TabBar]-(0)-|" options:0 metrics:nil views:views]];
    [self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-(==0)-[m_TabBar]-(==0)-[m_TabView]-(==0)-|" options:0 metrics:nil views:views]];
}

- (MMTabBarView*) tabBar
{
    return m_TabBar;
}

- (NSTabView*) tabView
{
    return m_TabView;
}

- (void) addPanel:(PanelView*)_panel
{
    FilePanelsTabbedBarItem *bar_item = [FilePanelsTabbedBarItem new];
    bar_item.hasCloseButton = true;
    
    NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:bar_item];
    item.view = _panel;
    item.initialFirstResponder = _panel;
    [m_TabView addTabViewItem:item];
}

- (PanelView*) current
{
    NSTabViewItem *it = m_TabView.selectedTabViewItem;
    if(!it)
        return nil;
    
    assert( objc_cast<PanelView>(it.view) );
    
    return (PanelView*)it.view;
}

- (unsigned) tabsCount
{
    return (unsigned)m_TabView.numberOfTabViewItems;
}

- (NSTabViewItem*) tabViewItemForController:(PanelController*)_controller
{
    PanelView *v = _controller.view;
    for(NSTabViewItem *it in m_TabView.tabViewItems)
        if(it.view == v)
            return it;
    return nil;
}

- (void) doShowTabBar
{
    if(!m_TabBarShown) {
        [self addSubview:m_TabBar];
        [self doLayoutWithTabs];
        m_TabBarShown = true;
    }
}

- (void) doHideTabBar
{
    if(m_TabBarShown) {
        [m_TabBar removeFromSuperview];
        [self doLayoutTabless];
        m_TabBarShown = false;
    }
}

- (bool) tabBarShown
{
    return m_TabBarShown;
}

- (void) setTabBarShown:(bool)tabBarShown
{
    if(m_TabBarShown == tabBarShown)
        return;
    if(m_TabBarShown && !tabBarShown)
        [self doHideTabBar];
    else if(!m_TabBarShown && tabBarShown)
        [self doShowTabBar];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    const auto resp_view = objc_cast<NSView>(self.window.firstResponder);
    if( !resp_view || ![resp_view isDescendantOf:m_TabView] )
        return [super performKeyEquivalent:theEvent];
    
    const auto characters = theEvent.charactersIgnoringModifiers;
    if ( characters.length != 1 )
        return [super performKeyEquivalent:theEvent];
    
    const auto mod = theEvent.modifierFlags;
    const auto unicode = [characters characterAtIndex:0];
    
    static ActionsShortcutsManager::ShortCut hk_prev, hk_next,
        hk_t1, hk_t2, hk_t3, hk_t4, hk_t5, hk_t6, hk_t7, hk_t8, hk_t9, hk_t10;
    static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater(
        {&hk_prev, &hk_next, &hk_t1, &hk_t2, &hk_t3, &hk_t4, &hk_t5,
        &hk_t6, &hk_t7, &hk_t8, &hk_t9, &hk_t10},
        {"panel.show_previous_tab", "panel.show_next_tab", "panel.show_tab_no_1", "panel.show_tab_no_2",
        "panel.show_tab_no_3", "panel.show_tab_no_4", "panel.show_tab_no_5", "panel.show_tab_no_6",
        "panel.show_tab_no_7", "panel.show_tab_no_8", "panel.show_tab_no_9", "panel.show_tab_no_10"});
    
    if( hk_prev.IsKeyDown(unicode, mod) ) {
        [self selectPreviousFilePanelTab];
        return true;
    }
    if( hk_next.IsKeyDown(unicode, mod) ) {
        [self selectNextFilePanelTab];
        return true;
    }
    if( hk_t1.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:0];
        return true;
    }
    if( hk_t2.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:1];
        return true;
    }
    if( hk_t3.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:2];
        return true;
    }
    if( hk_t4.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:3];
        return true;
    }
    if( hk_t5.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:4];
        return true;
    }
    if( hk_t6.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:5];
        return true;
    }
    if( hk_t7.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:6];
        return true;
    }
    if( hk_t8.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:7];
        return true;
    }
    if( hk_t9.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:8];
        return true;
    }
    if( hk_t10.IsKeyDown(unicode, mod) ) {
        [self selectTabAtIndex:9];
        return true;
    }
    
    return [super performKeyEquivalent:theEvent];
}

- (void) selectPreviousFilePanelTab
{
    unsigned long tabs = [m_TabBar numberOfTabViewItems];
    if(tabs == 1)
        return;
    
    unsigned long now = [m_TabBar indexOfTabViewItem:m_TabBar.selectedTabViewItem];
    if(now == NSNotFound)
        return;
    
    unsigned long willbe = now >= 1 ? now - 1 : tabs - 1;
    [m_TabBar selectTabViewItem:m_TabBar.tabView.tabViewItems[willbe]];
}

- (void) selectNextFilePanelTab
{
    unsigned long tabs = [m_TabBar numberOfTabViewItems];
    if(tabs == 1)
        return;
    
    unsigned long now = [m_TabBar indexOfTabViewItem:m_TabBar.selectedTabViewItem];
    if(now == NSNotFound)
        return;
    
    unsigned long willbe = now + 1 < tabs ? now + 1 : 0;
    [m_TabBar selectTabViewItem:m_TabBar.tabView.tabViewItems[willbe]];
}

- (int) selectedIndex
{
    auto it = m_TabView.selectedTabViewItem;
    if( !it )
        return -1;

    auto ind = [m_TabView indexOfTabViewItem:it];
    if( ind == NSNotFound )
        return -1;
    
    return (int)ind;
}

- (void) selectTabAtIndex:(int)_index
{
    if( _index < 0 )
        return;

    const auto tabs = (int)[m_TabBar numberOfTabViewItems];
    if( _index >= tabs )
        return;
    
    const auto now = (int)[m_TabBar indexOfTabViewItem:m_TabBar.selectedTabViewItem];
    if( now == _index )
        return;
    
    [m_TabBar selectTabViewItem:m_TabBar.tabView.tabViewItems[_index]];
}

@end
