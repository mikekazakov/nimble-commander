#include <Utility/FontExtras.h>
#include "PanelListViewGeometry.h"

constexpr short insets[4] = {7, 1, 5, 1};

// line height, text baseline, icon size
static tuple<short, short, short> GrabGeometryFromSystemFont( NSFont *_font )
{
    // hardcoded stuff to mimic Finder's layout
    short icon_size = 16;
    short line_height = 20;
    short text_baseline = 4;
    switch ( (int)floor(_font.pointSize+0.5) ) {
        case 10:
        case 11:
            line_height = 17;
            text_baseline = 5;
            break;
        case 12:
            line_height = 19;
            text_baseline = 5;
            break;
        case 13:
        case 14:
            line_height = 19;
            text_baseline = 4;
            break;
        case 15:
            line_height = 21;
            text_baseline = 6;
            break;
        case 16:
            line_height = 22;
            text_baseline = 6;
            break;
        default: {
            auto font_info = FontGeometryInfo( (__bridge CTFontRef)_font );
            line_height = font_info.LineHeight() + insets[1] + insets[3];
            text_baseline = insets[1] + font_info.Ascent();
            icon_size = font_info.LineHeight();
        }
    }
    return make_tuple(line_height, text_baseline, icon_size);
}

PanelListViewGeometry::PanelListViewGeometry():
    PanelListViewGeometry( [NSFont systemFontOfSize:NSFont.systemFontSize] )
{
}

PanelListViewGeometry::PanelListViewGeometry( NSFont* _font /*, .... */)
{
    tie(m_LineHeight, m_TextBaseLine, m_IconSize) = GrabGeometryFromSystemFont(_font);
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
