// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelViewDummyPresentation.h"

@implementation NCPanelViewDummyPresentation
@synthesize itemsInColumn;
@synthesize maxNumberOfVisibleItems;
@synthesize cursorPosition;

- (BOOL)isOpaque
{
    return true;
}

- (void)drawRect:(NSRect) [[maybe_unused]] _rect
{
}

- (void)onDataChanged
{
}

- (void)onVolatileDataChanged
{
}

- (void)setData:(nc::panel::data::Model *) [[maybe_unused]] _data
{
}

- (bool)isItemVisible:(int) [[maybe_unused]] _sorted_item_index
{
    return false;
}

- (void)setupFieldEditor:(NCPanelViewFieldEditor *) [[maybe_unused]] _editor
          forItemAtIndex:(int) [[maybe_unused]] _sorted_item_index
{
}

- (int)sortedItemPosAtPoint:(NSPoint) [[maybe_unused]] _window_point
              hitTestOption:(nc::panel::PanelViewHitTest::Options) [[maybe_unused]] _options
{
    return -1;
}

- (std::optional<NSRect>)frameOfItemAtIndex:(int)_sorted_item_index
{
    return {};
}

@end
