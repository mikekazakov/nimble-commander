// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontExtras.h>
#include "PanelListViewGeometry.h"
#include <array>
#include <cmath>

using nc::utility::FontGeometryInfo;

constexpr short insets[4] = {7, 1, 5, 1};

// font_size, double_icon, icon_size, line_height, text_baseline
using LayoutDataT = std::tuple<int8_t, int8_t, int8_t, int8_t, int8_t>;
static const std::array<LayoutDataT, 21> g_FixedLayoutData = {{
    std::make_tuple(10, 0,  0, 17, 5),
    std::make_tuple(10, 1, 16, 17, 5),
    std::make_tuple(10, 2, 32, 35, 14),
    std::make_tuple(11, 0,  0, 17, 5),
    std::make_tuple(11, 1, 16, 17, 5),
    std::make_tuple(11, 2, 32, 35, 14),
    std::make_tuple(12, 0,  9, 19, 5),
    std::make_tuple(12, 1, 16, 19, 5),
    std::make_tuple(12, 2, 32, 35, 13),
    std::make_tuple(13, 0,  0, 19, 4),
    std::make_tuple(13, 1, 16, 19, 4),
    std::make_tuple(13, 2, 32, 35, 12),
    std::make_tuple(14, 0,  0, 19, 4),
    std::make_tuple(14, 1, 16, 19, 4),
    std::make_tuple(14, 2, 32, 35, 12),
    std::make_tuple(15, 0,  0, 21, 6),
    std::make_tuple(15, 1, 16, 21, 6),
    std::make_tuple(15, 2, 32, 35, 12),
    std::make_tuple(16, 0,  0, 22, 6),
    std::make_tuple(16, 1, 16, 22, 6),
    std::make_tuple(16, 2, 32, 35, 12)
}};

// line height, text baseline, icon size
static std::tuple<short, short, short> GrabGeometryFromSystemFont( NSFont *_font, int _icon_scale )
{
    // hardcoded stuff to mimic Finder's layout
    short icon_size = 16;
    short line_height = 20;
    short text_baseline = 4;
    const int font_size = (int)std::floor(_font.pointSize+0.5);
    
    // check predefined values
    auto pit = find_if(begin(g_FixedLayoutData), end(g_FixedLayoutData), [&](auto &l) {
        return std::get<0>(l) == font_size && std::get<1>(l) == _icon_scale;
    });
    
    if( pit != end(g_FixedLayoutData) ) {
        // use hardcoded stuff to mimic Finder's layout
        icon_size = std::get<2>(*pit);
        line_height = std::get<3>(*pit);
        text_baseline = std::get<4>(*pit);
    }
    else {
        auto font_info = FontGeometryInfo( (__bridge CTFontRef)_font );
        line_height = short(font_info.LineHeight()) + insets[1] + insets[3];
        if( _icon_scale == 1 && line_height < 17 )
            line_height = 17;
        else if( _icon_scale == 2 && line_height < 35 )
            line_height = 35;
        
        text_baseline = insets[1] + short(font_info.Descent());
        icon_size = short(_icon_scale) * 16;
    }
    return std::make_tuple(line_height, text_baseline, icon_size);
}

PanelListViewGeometry::PanelListViewGeometry():
    PanelListViewGeometry( [NSFont systemFontOfSize:NSFont.systemFontSize], 1 )
{
}

PanelListViewGeometry::PanelListViewGeometry( NSFont* _font, int _icon_scale)
{
    std::tie(m_LineHeight, m_TextBaseLine, m_IconSize) = GrabGeometryFromSystemFont(_font, _icon_scale);
}
