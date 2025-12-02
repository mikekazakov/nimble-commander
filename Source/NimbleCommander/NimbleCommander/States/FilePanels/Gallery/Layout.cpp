// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Layout.h"

namespace nc::panel::gallery {

ItemLayout BuildItemLayout(unsigned _icon_size_px, unsigned _font_height, unsigned _text_lines)
{
    const unsigned char icon_margin = 2; // TODO: should it be not hardcoded?
    const unsigned char text_margin = 2; // TODO: should it be not hardcoded?
    
    ItemLayout il;
    il.icon_size = static_cast<unsigned short>(_icon_size_px);
    il.icon_left_margin = static_cast<unsigned char>( il.icon_size / 4 );
    il.icon_right_margin = static_cast<unsigned char>( il.icon_size / 4 );
    il.icon_top_margin = icon_margin;
    il.icon_bottom_margin = icon_margin;
    il.font_height = static_cast<unsigned char>(_font_height);
    il.text_lines = static_cast<unsigned char>(_text_lines);
    il.text_left_margin = text_margin;
    il.text_right_margin = text_margin;
    il.text_bottom_margin = text_margin;
    il.width = il.icon_size + il.icon_left_margin + il.icon_right_margin;
    il.height = static_cast<unsigned short>(il.icon_top_margin + il.icon_size + il.icon_bottom_margin + _font_height * _text_lines + il.text_bottom_margin);
    return il;
}

} // namespace nc::panel::gallery
