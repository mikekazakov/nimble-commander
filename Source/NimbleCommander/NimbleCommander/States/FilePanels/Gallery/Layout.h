// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::panel {

struct PanelGalleryViewLayout {
    unsigned char icon_scale = 1;
    unsigned char text_lines = 2;
    bool operator==(const PanelGalleryViewLayout &_rhs) const noexcept = default;
};

namespace gallery {

struct ItemLayout {
    unsigned short width = 0;     // combined width of the item
    unsigned short height = 0;    // combined height of the item
    unsigned short icon_size = 0; // icon_size == width == height
    unsigned char icon_top_margin = 0;
    unsigned char icon_bottom_margin = 0;
    unsigned char icon_left_margin = 0;  // = (width - icon_size) / 2
    unsigned char icon_right_margin = 0; // = (width - icon_size) / 2
    unsigned char font_height = 0;
    unsigned char font_baseline = 0;
    unsigned char text_lines = 0;
    unsigned char text_left_margin = 0;
    unsigned char text_right_margin = 0;
    unsigned char text_bottom_margin = 0;
    bool operator==(const ItemLayout &_rhs) const noexcept = default;
};

ItemLayout
BuildItemLayout(unsigned _icon_size_px, unsigned _font_height, unsigned _font_baseline, unsigned _text_lines);
} // namespace gallery

} // namespace nc::panel
