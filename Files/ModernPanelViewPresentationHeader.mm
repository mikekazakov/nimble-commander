//
//  ModernPanelViewPresentationHeader.cpp
//  Files
//
//  Created by Michael G. Kazakov on 13.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Utility/FontExtras.h>
#include "ModernPanelViewPresentationHeader.h"
#include "PanelData.h"

static const double g_TextInsetsInLine[4] = {7, 1, 5, 1};
static CGColorRef g_HeaderStrokeColorAct = CGColorCreateGenericRGB(176/255.0, 176/255.0, 176/255.0, 1.0);
static CGColorRef g_HeaderStrokeColorInact = CGColorCreateGenericRGB(225/255.0, 225/255.0, 225/255.0, 1.0);

static NSString *FormHumanReadableSortModeReprentation(PanelSortMode::Mode _mode)
{
    switch (_mode)
    {
        case PanelSortMode::SortByName:     return @"n";
        case PanelSortMode::SortByNameRev:  return @"N";
        case PanelSortMode::SortByExt:      return @"e";
        case PanelSortMode::SortByExtRev:   return @"E";
        case PanelSortMode::SortBySize:     return @"s";
        case PanelSortMode::SortBySizeRev:  return @"S";
        case PanelSortMode::SortByMTime:    return @"m";
        case PanelSortMode::SortByMTimeRev: return @"M";
        case PanelSortMode::SortByBTime:    return @"b";
        case PanelSortMode::SortByBTimeRev: return @"B";
        default:                            return @"?";
    }
}

ModernPanelViewPresentationHeader::ModernPanelViewPresentationHeader()
{
    m_Font = [NSFont systemFontOfSize:13];
    FontGeometryInfo info{(__bridge CTFontRef)m_Font};
    m_FontHeight = info.LineHeight();
    m_FontAscent = info.Ascent();
    m_Height = m_FontHeight + g_TextInsetsInLine[1] + g_TextInsetsInLine[3] + 1; // + 1 + 1
}

void ModernPanelViewPresentationHeader::Draw(bool _active,       // is panel active now?
                                             bool _wnd_active,
                                             double _width,      // panel width
                                             PanelSortMode::Mode _sort_mode)
{
    if(!_wnd_active)
        _active = false;
    
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    
    // draw header bg
    CGContextSaveGState(context);
    NSRect header_rect = NSMakeRect(0, 0, _width, m_Height - 1);
    if(_active) {
        static CGColorRef bg = CGColorCreateGenericRGB(1, 1, 1, 1);
        CGContextSetFillColorWithColor(context, bg);
        CGContextFillRect(context, header_rect);
    }
    else
        NSDrawWindowBackground(header_rect);
    CGContextRestoreGState(context);
    
    // draw header line separator.
    CGContextSetStrokeColorWithColor(context, _wnd_active ? g_HeaderStrokeColorAct : g_HeaderStrokeColorInact);
    NSPoint header_points[2] = { {0, m_Height - 0.5}, {_width, m_Height - 0.5} };
    CGContextStrokeLineSegments(context, header_points, 2);
    
    // draw title text itself
    [m_Title drawWithRect:NSMakeRect(20,
                                     g_TextInsetsInLine[1] + m_FontAscent,
                                     _width - 25,
                                     m_FontHeight)
                    options:0];
    
    // prepare panel sort mode
    if( _sort_mode != m_LastSortMode ) {
        static const NSParagraphStyle *header_text_pstyle = ^{
            NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
            p.alignment = NSCenterTextAlignment;
            return p.copy;
        }();
        
        static NSDictionary *header_text_attr = @{NSFontAttributeName: m_Font,
                                                  NSParagraphStyleAttributeName: header_text_pstyle};
        m_ModeStr = [[NSAttributedString alloc] initWithString:FormHumanReadableSortModeReprentation(_sort_mode)
                                                    attributes:header_text_attr];
        m_LastSortMode = _sort_mode;
    }
 
    // draw panel sort mode
    [m_ModeStr drawWithRect:NSMakeRect(0,
                             g_TextInsetsInLine[1] + m_FontAscent,
                             20,
                             m_FontHeight)
                    options:0];
}

void ModernPanelViewPresentationHeader::SetTitle(NSString *_title)
{
    static const NSParagraphStyle *header_text_pstyle = []{
        NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
        p.alignment = NSCenterTextAlignment;
        p.lineBreakMode = NSLineBreakByTruncatingHead;
        return p.copy;
    }();
    
    NSDictionary *header_text_attr = @{NSFontAttributeName: m_Font,
                                       NSParagraphStyleAttributeName: header_text_pstyle};
    m_Title = [[NSAttributedString alloc] initWithString:_title
                                              attributes:header_text_attr];
}
