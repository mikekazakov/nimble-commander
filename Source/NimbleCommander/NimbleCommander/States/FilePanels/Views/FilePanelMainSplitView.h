// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>
#import "FilePanelsTabbedHolder.h"

namespace nc::utility {
class ActionsShortcutsManager;
}

@class PanelView;

@interface FilePanelMainSplitView : NSSplitView <NSSplitViewDelegate>

- (id)initWithFrame:(NSRect)_frame NS_UNAVAILABLE;
- (id)initWithFrame:(NSRect)_frame
    actionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_actions_shortcuts_manager;

- (void)swapViews;
- (void)collapseLeftView;
- (void)expandLeftView;
- (void)collapseRightView;
- (void)expandRightView;

@property(nonatomic, readonly) bool anyCollapsed;
@property(nonatomic, readonly) bool isLeftCollapsed;
@property(nonatomic, readonly) bool isRightCollapsed;

@property(nonatomic, readonly) bool anyOverlayed;
@property(nonatomic, readonly) bool isLeftOverlayed;
@property(nonatomic, readonly) bool isRightOverlayed;

@property(nonatomic, readonly) bool anyCollapsedOrOverlayed;
- (bool)isViewCollapsedOrOverlayed:(NSView *)_v;

@property(nonatomic) NSView *leftOverlay;
@property(nonatomic) NSView *rightOverlay;

@property(nonatomic, readonly) FilePanelsTabbedHolder *leftTabbedHolder;
@property(nonatomic, readonly) FilePanelsTabbedHolder *rightTabbedHolder;

@end
