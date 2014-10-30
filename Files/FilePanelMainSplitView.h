//
//  FilePanelMainSplitView.h
//  Files
//
//  Created by Michael G. Kazakov on 05.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FilePanelsTabbedHolder.h"

@class PanelView;

@interface FilePanelMainSplitView : NSSplitView<NSSplitViewDelegate>

- (void) SwapViews;

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
