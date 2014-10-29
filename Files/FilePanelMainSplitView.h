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

- (bool) AnyCollapsed;
- (bool) LeftCollapsed;
- (bool) RightCollapsed;

- (bool) AnyOverlayed;
- (bool) LeftOverlayed;
- (bool) RightOverlayed;

- (bool) AnyCollapsedOrOverlayed;
- (bool) IsViewCollapsedOrOverlayed:(NSView*)_v;

@property (nonatomic) NSView* leftOverlay;
@property (nonatomic) NSView* rightOverlay;

@property (nonatomic) FilePanelsTabbedHolder *leftTabbedHolder;
@property (nonatomic) FilePanelsTabbedHolder *rightTabbedHolder;

@end
