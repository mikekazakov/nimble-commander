//
//  ModernPanelViewPresentationHeader.cpp
//  Files
//
//  Created by Michael G. Kazakov on 13.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "ModernPanelViewPresentationHeader.h"
#import "FontExtras.h"
#import "PanelData.h"

const double g_TextInsetsInLine[4] = {7, 1, 5, 1};
static CGColorRef g_HeaderStrokeColor = CGColorCreateGenericRGB(102/255.0, 102/255.0, 102/255.0, 1.0);

static NSShadow* ActiveTextShadow()
{
    static dispatch_once_t onceToken;
    static NSShadow *shadow;
    dispatch_once(&onceToken, ^{
        shadow = [NSShadow new];
        shadow.shadowBlurRadius = 1;
        shadow.shadowColor = [NSColor colorWithDeviceRed:0.83 green:0.93 blue:1 alpha:1];
        shadow.shadowOffset = NSMakeSize(0, -1);
    });
    return shadow;
}

static NSShadow* InactiveTextShadow()
{
    static dispatch_once_t onceToken;
    static NSShadow *shadow;
    dispatch_once(&onceToken, ^{
        shadow = [NSShadow new];
        shadow.shadowBlurRadius = 1;
        shadow.shadowColor = [NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:0.9];
        shadow.shadowOffset = NSMakeSize(0, -1);
    });
    return shadow;
}

static CGGradientRef ActiveTextGradient()
{
    static dispatch_once_t onceToken;
    static CGGradientRef gradient;
    dispatch_once(&onceToken, ^{
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        const CGFloat outer_color[3] = { 200/255.0, 230/255.0, 245/255.0 };
        const CGFloat inner_color[3] = { 150/255.0, 196/255.0, 240/255.0 };
        CGFloat components[] =
        {
            outer_color[0], outer_color[1], outer_color[2], 1.0,
            inner_color[0], inner_color[1], inner_color[2], 1.0,
            inner_color[0], inner_color[1], inner_color[2], 1.0,
            outer_color[0], outer_color[1], outer_color[2], 1.0
        };
        CGFloat locations[] = {0.0, 0.45, 0.55, 1.0};
        gradient = CGGradientCreateWithColorComponents(color_space, components, locations, 4);
        CGColorSpaceRelease(color_space);
    });
    return gradient;
}

static CGGradientRef InactiveTextGradient()
{
    static dispatch_once_t onceToken;
    static CGGradientRef gradient;
    dispatch_once(&onceToken, ^{
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        const CGFloat upper_color[3] = { 220/255.0, 220/255.0, 220/255.0 };
        const CGFloat bottom_color[3] = { 200/255.0, 200/255.0, 200/255.0 };
        CGFloat components[] =
        {
            upper_color[0], upper_color[1], upper_color[2], 1.0,
            upper_color[0], upper_color[1], upper_color[2], 1.0,
            bottom_color[0], bottom_color[1], bottom_color[2], 1.0,
            bottom_color[0], bottom_color[1], bottom_color[2], 1.0
        };
        CGFloat locations[] = {0.0, 0.45, 0.7, 1.0};
        gradient = CGGradientCreateWithColorComponents(color_space, components, locations, 4);
        CGColorSpaceRelease(color_space);
    });
    return gradient;
}

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

void ModernPanelViewPresentationHeader::SetFont(NSFont *_font)
{
    m_Font = _font;
    m_FontHeight = GetLineHeightForFont((__bridge CTFontRef)m_Font, &m_FontAscent);
    m_Height = m_FontHeight + g_TextInsetsInLine[1] + g_TextInsetsInLine[3] + 1; // + 1 + 1
}

void ModernPanelViewPresentationHeader::Draw(const string& _path, // a path to draw
                                             bool _active,       // is panel active now?
                                             double _width,      // panel width
                                             PanelSortMode::Mode _sort_mode)
{
    PrepareToDraw(_path, _active, _sort_mode);
    
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    
    // draw header gradient
    CGContextSaveGState(context);
    NSRect header_rect = NSMakeRect(0, 0, _width, m_Height - 1);
    CGContextAddRect(context, header_rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context,
                                _active ? ActiveTextGradient() : InactiveTextGradient(),
                                header_rect.origin,
                                NSMakePoint(header_rect.origin.x,
                                            header_rect.origin.y + header_rect.size.height),
                                0);
    CGContextRestoreGState(context);
    
    // draw header line separator.
    CGContextSetStrokeColorWithColor(context, g_HeaderStrokeColor);
    NSPoint header_points[2] = { {0, m_Height - 0.5}, {_width, m_Height - 0.5} };
    CGContextStrokeLineSegments(context, header_points, 2);
    
    // draw path text itself
    [m_PathStr drawWithRect:NSMakeRect(20,
                                     g_TextInsetsInLine[1] + m_FontAscent,
                                     _width - 40,
                                     m_FontHeight)
                    options:0];
    
    // draw panel sort mode
    [m_ModeStr drawWithRect:NSMakeRect(0,
                             g_TextInsetsInLine[1] + m_FontAscent,
                             20,
                             m_FontHeight)
                    options:0];
}

void ModernPanelViewPresentationHeader::PrepareToDraw(const string& _path, bool _active, PanelSortMode::Mode _sort_mode)
{
    if(m_LastHeaderPath == _path &&
       m_LastActive == _active &&
       m_LastSortMode == _sort_mode)
        return; // current state is ok
    
    static const NSParagraphStyle *header_text_pstyle = ^{
        NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
        p.alignment = NSCenterTextAlignment;
        p.lineBreakMode = NSLineBreakByTruncatingHead;
        return p.copy;
    }();

    NSShadow *header_text_shadow = _active ? ActiveTextShadow() : InactiveTextShadow();
    
    NSDictionary *header_text_attr =@{NSFontAttributeName: m_Font,
                                      NSParagraphStyleAttributeName: header_text_pstyle,
                                      NSShadowAttributeName: header_text_shadow};

    NSString *header_string = [NSString stringWithUTF8String:_path.c_str()];
    if(header_string == nil) header_string = @"...";
    
    m_PathStr = [[NSAttributedString alloc] initWithString:header_string
                                                attributes:header_text_attr];
    
    m_ModeStr = [[NSAttributedString alloc] initWithString:FormHumanReadableSortModeReprentation(_sort_mode)
                                                attributes:header_text_attr];

    m_LastActive = _active;
    m_LastHeaderPath = _path;
    m_LastSortMode = _sort_mode;
}
