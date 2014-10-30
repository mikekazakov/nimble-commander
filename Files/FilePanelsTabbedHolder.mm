//
//  FilePanelsTabbedHolder.mm
//  Files
//
//  Created by Michael G. Kazakov on 28/10/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "FilePanelsTabbedHolder.h"
#import "3rd_party/MMTabBarView/MMTabBarView/MMTabBarView.h"

@implementation FilePanelsTabbedHolder
{
    MMTabBarView    *m_TabBar;
    NSTabView       *m_TabView;
}

- (id) initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self) {
        
        self.orientation = NSUserInterfaceLayoutOrientationVertical;
        self.edgeInsets = NSEdgeInsetsMake(0, 0, 0, 0);
        self.spacing = 0;
        
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
        [self addView:m_TabView inGravity:NSStackViewGravityBottom];
        
        
        m_TabBar = [[MMTabBarView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
        m_TabBar.translatesAutoresizingMaskIntoConstraints = NO;
        m_TabBar.tabView = m_TabView;
        m_TabBar.showAddTabButton = true;
        [m_TabBar setStyleNamed:@"Adium"];
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
                                                              constant:22]];
        [self addView:m_TabBar inGravity:NSStackViewGravityTop];
        
        m_TabView.delegate = m_TabBar;
    }
    return self;
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
    NSTabViewItem *item = [[NSTabViewItem alloc] initWithIdentifier:@"Test"];
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

@end
