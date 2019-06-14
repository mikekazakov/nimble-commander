// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewDummyPresentation.h"

@implementation NCPanelViewDummyPresentation

- (BOOL)isOpaque
{
    return true;
}

- (void)drawRect:(NSRect) [[maybe_unused]] _rect
{
}

- (void)dataChanged
{
}

- (void)syncVolatileData
{
}

- (void)setData:(nc::panel::data::Model*)[[maybe_unused]] _data
{
}

- (bool)isItemVisible:(int)[[maybe_unused]] _sorted_item_index
{
    return false;
}

- (void)setupFieldEditor:(NSScrollView*)[[maybe_unused]] _editor
          forItemAtIndex:(int)[[maybe_unused]] _sorted_item_index
{
}

- (void)onScrollToBeginning:(NSEvent*)[[maybe_unused]] _event
{
}

- (void)onScrollToEnd:(NSEvent*)[[maybe_unused]] _event
{
}

- (void)onPageUp:(NSEvent*)[[maybe_unused]] _event
{
}

- (void)onPageDown:(NSEvent*)[[maybe_unused]] _event
{
}

- (int)sortedItemPosAtPoint:(NSPoint) [[maybe_unused]] _window_point
              hitTestOption:(nc::panel::PanelViewHitTest::Options) [[maybe_unused]] _options
{
    return -1;
}

@end
