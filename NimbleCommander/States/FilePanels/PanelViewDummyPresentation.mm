// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewDummyPresentation.h"

@implementation NCPanelViewDummyPresentation

- (BOOL) isOpaque
{
    return true;
}

- (void) drawRect:(NSRect)dirtyRect
{
}

- (void) dataChanged{}
- (void) syncVolatileData{}
- (void) setData:(nc::panel::data::Model*)_data{}
- (bool) isItemVisible:(int)_sorted_item_index{ return false; }

- (void) setupFieldEditor:(NSScrollView*)_editor forItemAtIndex:(int)_sorted_item_index {}

- (void) onScrollToBeginning:(NSEvent*)_event {}
- (void) onScrollToEnd:(NSEvent*)_event {}
- (void) onPageUp:(NSEvent*)_event {}
- (void) onPageDown:(NSEvent*)_event {}

- (int) sortedItemPosAtPoint:(NSPoint)_window_point
               hitTestOption:(nc::panel::PanelViewHitTest::Options)_options { return -1; }

@end

