#include <Utility/FontExtras.h>
#include "PanelListViewGeometry.h"

constexpr short insets[4] = {7, 1, 5, 1};

// font_size, double_icon, icon_size, line_height, text_baseline
static const array< tuple<int8_t, int8_t, int8_t, int8_t, int8_t>, 21> g_FixedLayoutData = {{
    make_tuple(10, 0,  0, 17, 5),
    make_tuple(10, 1, 16, 17, 5),
    make_tuple(10, 2, 32, 35, 14),
    make_tuple(11, 0,  0, 17, 5),
    make_tuple(11, 1, 16, 17, 5),
    make_tuple(11, 2, 32, 35, 14),
    make_tuple(12, 0,  9, 19, 5),
    make_tuple(12, 1, 16, 19, 5),
    make_tuple(12, 2, 32, 35, 13),
    make_tuple(13, 0,  0, 19, 4),
    make_tuple(13, 1, 16, 19, 4),
    make_tuple(13, 2, 32, 35, 12),
    make_tuple(14, 0,  0, 19, 4),
    make_tuple(14, 1, 16, 19, 4),
    make_tuple(14, 2, 32, 35, 12),
    make_tuple(15, 0,  0, 21, 6),
    make_tuple(15, 1, 16, 21, 6),
    make_tuple(15, 2, 32, 35, 12),
    make_tuple(16, 0,  0, 22, 6),
    make_tuple(16, 1, 16, 22, 6),
    make_tuple(16, 2, 32, 35, 12)
}};

// line height, text baseline, icon size
static tuple<short, short, short> GrabGeometryFromSystemFont( NSFont *_font, int _icon_scale )
{
    // hardcoded stuff to mimic Finder's layout
    short icon_size = 16;
    short line_height = 20;
    short text_baseline = 4;
    const int font_size = (int)floor(_font.pointSize+0.5);
    
    // check predefined values
    auto pit = find_if(begin(g_FixedLayoutData), end(g_FixedLayoutData), [&](auto &l) {
        return get<0>(l) == font_size && get<1>(l) == _icon_scale;
    });
    
    if( pit != end(g_FixedLayoutData) ) {
        // use hardcoded stuff to mimic Finder's layout
        icon_size = get<2>(*pit);
        line_height = get<3>(*pit);
        text_baseline = get<4>(*pit);
    }
    else {
        auto font_info = FontGeometryInfo( (__bridge CTFontRef)_font );
        line_height = font_info.LineHeight() + insets[1] + insets[3];
        if( _icon_scale == 1 && line_height < 17 )
            line_height = 17;
        else if( _icon_scale == 2 && line_height < 35 )
            line_height = 35;
        
        text_baseline = insets[1] + font_info.Descent();
        icon_size = _icon_scale * 16;
    }
    return make_tuple(line_height, text_baseline, icon_size);
}

PanelListViewGeometry::PanelListViewGeometry():
    PanelListViewGeometry( [NSFont systemFontOfSize:NSFont.systemFontSize], 1 )
{
}

PanelListViewGeometry::PanelListViewGeometry( NSFont* _font, int _icon_scale)
{
    tie(m_LineHeight, m_TextBaseLine, m_IconSize) = GrabGeometryFromSystemFont(_font, _icon_scale);
}


//static PanelBriefViewItemLayoutConstants BuildItemsLayout( NSFont *_font /* double icon size*/ )
//{
//    assert( _font );
//    static const int insets[4] = {7, 1, 5, 1};
//    
//    // TODO: generic case for custom font (not SF)
//    
//    // hardcoded stuff to mimic Finder's layout
//    int icon_size = 16;
//    int line_height = 20;
//    int text_baseline = 4;
//    switch ( (int)floor(_font.pointSize+0.5) ) {
//        case 10:
//        case 11:
//            line_height = 17;
//            text_baseline = 5;
//            break;
//        case 12:
//            line_height = 19;
//            text_baseline = 5;
//            break;
//        case 13:
//        case 14:
//            line_height = 19;
//            text_baseline = 4;
//            break;
//        case 15:
//            line_height = 21;
//            text_baseline = 6;
//            break;
//        case 16:
//            line_height = 22;
//            text_baseline = 6;
//            break;
//        default: {
//            auto font_info = FontGeometryInfo( (__bridge CTFontRef)_font );
//            line_height = font_info.LineHeight() + insets[1] + insets[3];
//            text_baseline = insets[1] + font_info.Ascent();
//            icon_size = font_info.LineHeight();
//        }
//    }
//    
//    PanelBriefViewItemLayoutConstants lc;
//    lc.inset_left = insets[0]/*7*/;
//    lc.inset_top = insets[1]/*1*/;
//    lc.inset_right = insets[2]/*5*/;
//    lc.inset_bottom = insets[3]/*1*/;
//    lc.icon_size = icon_size/*16*/;
//    lc.font_baseline = text_baseline /*4*/;
//    lc.item_height = line_height /*20*/;
//    
//    return lc;
//}
