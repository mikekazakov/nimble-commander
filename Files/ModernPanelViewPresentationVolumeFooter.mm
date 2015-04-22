//
//  ModernPanelViewPresentationVolumeFooter.cpp
//  Files
//
//  Created by Michael G. Kazakov on 14.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "FontExtras.h"
#include "ModernPanelViewPresentationVolumeFooter.h"
#import "ByteCountFormatter.h"

static const double g_TextInsetsInLine[4] = {7, 1, 5, 1};

ModernPanelViewPresentationVolumeFooter::ModernPanelViewPresentationVolumeFooter()
{
    m_Font = [NSFont systemFontOfSize:11];
    m_FontHeight = GetLineHeightForFont((__bridge CTFontRef)m_Font, &m_FontAscent);
    m_Height = m_FontHeight + g_TextInsetsInLine[1] + g_TextInsetsInLine[3] + 1; // + 1 + 1
}

void ModernPanelViewPresentationVolumeFooter::Draw(const VFSStatFS &_stat, bool _wnd_active, double _start_y, double _width)
{
    PrepareToDraw(_stat);
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    
    const double gap = 10;
    const double text_y_off = _start_y + g_TextInsetsInLine[1] + m_FontAscent;
    

    // Draw background
    NSRect footer_rect = NSMakeRect(0, _start_y + 1, _width, m_Height - 1);
    NSDrawWindowBackground(footer_rect);
    
    // Footer line separator.
    static CGColorRef divider_stroke_color_act = CGColorCreateGenericRGB(160/255.0, 160/255.0, 160/255.0, 1.0);
    static CGColorRef divider_stroke_color_act_inact = CGColorCreateGenericRGB(225/255.0, 225/255.0, 225/255.0, 1.0);
    CGContextSetStrokeColorWithColor(context, _wnd_active ? divider_stroke_color_act : divider_stroke_color_act_inact);
    NSPoint footer_points[2] = { {0, _start_y + 0.5}, {_width, _start_y + 0.5} };
    CGContextStrokeLineSegments(context, footer_points, 2);
    
    // draw free space information
    [m_FreeSpace drawWithRect:NSMakeRect(gap, text_y_off, _width - 2.*gap, m_FontHeight)
                      options:0];

    // if we have any free space on footer - draw volume name
    double width_left = _width - 2.*gap - m_FreeSpace.size.width;
    if(width_left > 0)
        [m_VolumeName drawWithRect:NSMakeRect(gap, text_y_off, width_left, m_FontHeight)
                           options:0];
}

void ModernPanelViewPresentationVolumeFooter::PrepareToDraw(const VFSStatFS &_stat)
{
    if(m_CurrentStat == _stat)
        return;
    
    m_CurrentStat = _stat;
    
    static NSDictionary *attr1, *attr2;
    static once_flag once;
    call_once(once, [=]{
        NSMutableParagraphStyle *par1 = [NSMutableParagraphStyle new];
        par1.alignment = NSLeftTextAlignment;
        par1.lineBreakMode = NSLineBreakByTruncatingTail;
        attr1 = @{NSFontAttributeName:m_Font,
                  NSParagraphStyleAttributeName:par1
                  };
        
        NSMutableParagraphStyle *par2 = [NSMutableParagraphStyle new];
        par2.alignment = NSRightTextAlignment;
        par2.lineBreakMode = NSLineBreakByClipping;
        attr2 = @{NSFontAttributeName:m_Font,
                  NSParagraphStyleAttributeName:par2
                  };
    });

    NSString *name_str = [NSString stringWithUTF8String:m_CurrentStat.volume_name.c_str()];
    m_VolumeName = [[NSAttributedString alloc] initWithString:name_str
                                                   attributes:attr1];
    
    NSString *avail = [NSString stringWithFormat:NSLocalizedString(@"%@ available",
                                                                   "Panels bottom volume bar, showing amount of bytes available"),
                              ByteCountFormatter::Instance().ToNSString(m_CurrentStat.avail_bytes, ByteCountFormatter::Adaptive6)];
    m_FreeSpace = [[NSAttributedString alloc] initWithString:avail
                                                  attributes:attr2];
}
