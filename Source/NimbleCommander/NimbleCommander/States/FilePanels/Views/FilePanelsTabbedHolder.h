// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::utility {
class ActionsShortcutsManager;
}

@class MMTabBarView;
@class PanelView;
@class PanelController;

@interface FilePanelsTabbedHolder : NSView

@property(nonatomic, readonly) MMTabBarView *tabBar;
@property(nonatomic, readonly) NSTabView *tabView;
@property(nonatomic, readonly)
    PanelView *current; // can return nil in case if there's no panels inserted or in some other weird cases
@property(nonatomic, readonly) int selectedIndex; // return -1 if no PanelView is selected
@property(nonatomic, readonly) unsigned tabsCount;
@property(nonatomic) bool tabBarShown;

- (id)initWithFrame:(NSRect)_frame_rect NS_UNAVAILABLE;
- (id)initWithFrame:(NSRect)_frame_rect
    actionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager;

- (void)addPanel:(PanelView *)_panel;
- (NSTabViewItem *)tabViewItemForController:(PanelController *)_controller;

- (void)selectPreviousFilePanelTab;
- (void)selectNextFilePanelTab;
- (void)selectTabAtIndex:(int)index;

@end
