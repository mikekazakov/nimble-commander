//
//  FilePanelsTabbedHolder.mm
//  Files
//
//  Created by Michael G. Kazakov on 28/10/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "FilePanelsTabbedHolder.h"
#import "3rd_party/MMTabBarView/MMTabBarView/MMTabBarView.h"
#import "3rd_party/MMTabBarView/MMTabBarView/MMTabBarItem.h"
#import "PanelController.h"
#import "PanelView.h"
#import "MMTabBarStyle.h"

@interface FilePanelsTabbedBarItem : NSObject <MMTabBarItem>

@property (assign) BOOL hasCloseButton;

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
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [MMTabBarView registerTabStyleClass:MMTabBarStyle.class];
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
        [m_TabView addConstraint:[NSLayoutConstraint constraintWithItem:m_TabView
                                                              attribute:NSLayoutAttributeHeight
                                                              relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1.0
                                                               constant:50]];
        [self addSubview:m_TabView];
        
        m_TabBar = [[MMTabBarView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        m_TabBar.translatesAutoresizingMaskIntoConstraints = NO;
        m_TabBar.tabView = m_TabView;
        m_TabBar.showAddTabButton = true;
        m_TabBar.canCloseOnlyTab = false;
        m_TabBar.disableTabClose = false;
        m_TabBar.onlyShowCloseOnHover = true;
        m_TabBar.useOverflowMenu = false;
        m_TabBar.buttonMinWidth = 100;
        m_TabBar.buttonMaxWidth = 2000;
        m_TabBar.buttonOptimumWidth = 2000;
        [m_TabBar setStyleNamed:@"Files"];
        [m_TabBar addConstraint:[NSLayoutConstraint constraintWithItem:m_TabBar
                                                             attribute:NSLayoutAttributeWidth
                                                             relatedBy:NSLayoutRelationGreaterThanOrEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1.0
                                                              constant:50]];
        [m_TabBar addConstraint:[NSLayoutConstraint constraintWithItem:m_TabBar
                                                             attribute:NSLayoutAttributeHeight
                                                             relatedBy:NSLayoutRelationEqual
                                                                toItem:nil
                                                             attribute:NSLayoutAttributeNotAnAttribute
                                                            multiplier:1.0
                                                              constant:m_TabBar.heightOfTabBarButtons]];
        m_TabView.delegate = m_TabBar;
        
        [self doLayoutTabless];
    }
    return self;
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
    
    assert( [it.view isKindOfClass:PanelView.class] );
    
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

@end
