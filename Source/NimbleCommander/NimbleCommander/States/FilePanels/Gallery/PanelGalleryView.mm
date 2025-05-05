// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelGalleryView.h"

using namespace nc;
using namespace nc::panel;

@implementation PanelGalleryView {
    data::Model *m_Data;
    PanelGalleryViewLayout m_Layout;
}

- (instancetype)initWithFrame:(NSRect)_frame
{
    if( self = [super initWithFrame:_frame] ) {
        m_Data = nullptr;
    }

    return self;
}

- (int)itemsInColumn
{
    // TODO: implement
    return 1; // ??
}

- (int)maxNumberOfVisibleItems
{
    // TODO: implement
    return 5;
}

- (int)cursorPosition
{
    // TODO: implement
    return -1;
}

- (void)setCursorPosition:(int)_cursor_position
{
    // TODO: implement
}

- (void)onDataChanged
{
    // TODO: implement
}

- (void)onVolatileDataChanged
{
    // TODO: implement
}

- (void)setData:(data::Model *)_data
{
    m_Data = _data;
}

- (bool)isItemVisible:(int)_sorted_item_index
{
    // TODO: implement
    return false;
}

- (void)setupFieldEditor:(NCPanelViewFieldEditor *)_editor forItemAtIndex:(int)_sorted_item_index
{
    // TODO: implement
}

- (int)sortedItemPosAtPoint:(NSPoint)_window_point hitTestOption:(PanelViewHitTest::Options)_options
{
    // TODO: implement
    return -1;
}

- (std::optional<NSRect>)frameOfItemAtIndex:(int)_sorted_item_index
{
    // TODO: implement
    return {};
}

- (PanelGalleryViewLayout)galleryLayout
{
    return m_Layout;
}

- (void)setGalleryLayout:(nc::panel::PanelGalleryViewLayout)_layout
{
    // TODO: implement
    m_Layout = _layout;
}

@end
