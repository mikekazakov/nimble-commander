//
//  PanelController+DragAndDrop.h
//  Files
//
//  Created by Michael G. Kazakov on 27.01.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

@interface PanelController (DragAndDrop)

// drag source
+ (NSArray*) acceptedDragAndDropTypes;
- (void) initiateDragFromView:(NSView*)_view itemNo:(int)_sort_pos byEvent:(NSEvent *)_event;

// drag target
- (NSDragOperation) validateDraggingOperation:(id <NSDraggingInfo>)_dragging
                                 forPanelItem:(int)_sorted_index; // -1 means "whole" panel

- (bool) performDragOperation:(id<NSDraggingInfo>)_dragging
                 forPanelItem:(int)_sorted_index; // -1 means "whole" panel

@end
