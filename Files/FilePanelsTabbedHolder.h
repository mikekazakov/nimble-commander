//
//  FilePanelsTabbedHolder.h
//  Files
//
//  Created by Michael G. Kazakov on 28/10/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

@class MMTabBarView;
@class PanelView;
@class PanelController;

@interface FilePanelsTabbedHolder : NSView

@property (nonatomic, readonly) MMTabBarView *tabBar;
@property (nonatomic, readonly) NSTabView    *tabView;
@property (nonatomic, readonly) PanelView    *current; // can return nil in case if there's no panels inserted or in some other weird cases
@property (nonatomic, readonly) unsigned     tabsCount;
@property (nonatomic)           bool         tabBarShown;

- (void) addPanel:(PanelView*)_panel;
- (NSTabViewItem*) tabViewItemForController:(PanelController*)_controller;

- (void) selectPreviousFilePanelTab;
- (void) selectNextFilePanelTab;

@end
