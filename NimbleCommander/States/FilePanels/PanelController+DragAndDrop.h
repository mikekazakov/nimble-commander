#pragma once
#include "PanelController.h"

@interface PanelController (DragAndDrop)

// drag source
- (void) initiateDragFromView:(NSView*)_view itemNo:(int)_sort_pos byEvent:(NSEvent *)_event;


@end
