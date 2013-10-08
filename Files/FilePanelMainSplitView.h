//
//  FilePanelMainSplitView.h
//  Files
//
//  Created by Michael G. Kazakov on 05.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PanelView;

@interface FilePanelMainSplitView : NSSplitView<NSSplitViewDelegate>

- (void) SetBasicViews:(PanelView*)_v1 second:(PanelView*)_v2;
- (void) SwapViews;

- (bool) AnyCollapsed;
- (bool) LeftCollapsed;
- (bool) RightCollapsed;

- (void) SetLeftOverlay:(NSView*)_o;
- (void) SetRightOverlay:(NSView*)_o;

- (bool) AnyOverlayed;
- (bool) LeftOverlayed;
- (bool) RightOverlayed;

- (bool) AnyCollapsedOrOverlayed;
- (bool) IsViewCollapsedOrOverlayed:(NSView*)_v;
@end
