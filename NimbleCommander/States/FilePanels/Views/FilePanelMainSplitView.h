// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <Cocoa/Cocoa.h>
#import "FilePanelsTabbedHolder.h"

@class PanelView;

@interface FilePanelMainSplitView : NSSplitView<NSSplitViewDelegate>

- (void) swapViews;
- (void) collapseLeftView;
- (void) expandLeftView;
- (void) collapseRightView;
- (void) expandRightView;

@property (nonatomic, readonly) bool anyCollapsed;
@property (nonatomic, readonly) bool isLeftCollapsed;
@property (nonatomic, readonly) bool isRightCollapsed;

@property (nonatomic, readonly) bool anyOverlayed;
@property (nonatomic, readonly) bool isLeftOverlayed;
@property (nonatomic, readonly) bool isRightOverlayed;

@property (nonatomic, readonly) bool anyCollapsedOrOverlayed;
- (bool) isViewCollapsedOrOverlayed:(NSView*)_v;

@property (nonatomic) NSView* leftOverlay;
@property (nonatomic) NSView* rightOverlay;

@property (nonatomic) FilePanelsTabbedHolder *leftTabbedHolder;
@property (nonatomic) FilePanelsTabbedHolder *rightTabbedHolder;

@end
