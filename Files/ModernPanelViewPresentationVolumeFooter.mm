//
//  ModernPanelViewPresentationVolumeFooter.cpp
//  Files
//
//  Created by Michael G. Kazakov on 14.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "FontExtras.h"
#include "ModernPanelViewPresentationVolumeFooter.h"

static const double g_TextInsetsInLine[4] = {7, 1, 5, 1};
static CGColorRef g_HeaderStrokeColor = CGColorCreateGenericRGB(102/255.0, 102/255.0, 102/255.0, 1.0);

static NSShadow* TextShadow()
{
    static dispatch_once_t onceToken;
    static NSShadow *shadow;
    dispatch_once(&onceToken, ^{
        shadow = [NSShadow new];
        shadow.shadowBlurRadius = 1;
        shadow.shadowColor = [NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:0.8];
        shadow.shadowOffset = NSMakeSize(0, -1);
    });
    return shadow;
}

enum {
    kUnitStringBinaryUnits     = 1 << 0,
    kUnitStringOSNativeUnits   = 1 << 1,
    kUnitStringLocalizedFormat = 1 << 2
};

static NSString* unitStringFromBytes(uint64_t _bytes, uint8_t flags)
{
    // TODO: use static allocated formatter
    
    static const char units[] = { '\0', 'k', 'M', 'G', 'T', 'P', 'E', 'Z', 'Y' };
    static int maxUnits = sizeof units - 1;
    
//    int multiplier = (flags & kUnitStringOSNativeUnits && !leopardOrGreater() || flags & kUnitStringBinaryUnits) ? 1024 : 1000;
//    int multiplier = 1024;
    int multiplier = 1000;
    int exponent = 0;
    double bytes = _bytes;
    
    while (bytes >= multiplier && exponent < maxUnits) {
        bytes /= multiplier;
        exponent++;
    }
    NSNumberFormatter* formatter = [[NSNumberFormatter alloc] init];
    [formatter setMaximumFractionDigits:2];
    if (flags & kUnitStringLocalizedFormat) {
        [formatter setNumberStyle: NSNumberFormatterDecimalStyle];
    }
    // Beware of reusing this format string. -[NSString stringWithFormat] ignores \0, *printf does not.
    return [NSString stringWithFormat:@"%@ %cB", [formatter stringFromNumber: [NSNumber numberWithDouble: bytes]], units[exponent]];
}

ModernPanelViewPresentationVolumeFooter::ModernPanelViewPresentationVolumeFooter()
{
    m_Font = [NSFont fontWithName:@"Lucida Grande" size:11];
    m_FontHeight = GetLineHeightForFont((__bridge CTFontRef)m_Font, &m_FontAscent);
    m_Height = m_FontHeight + g_TextInsetsInLine[1] + g_TextInsetsInLine[3] + 1; // + 1 + 1
}

void ModernPanelViewPresentationVolumeFooter::Draw(const VFSStatFS &_stat, double _start_y, double _width)
{
    PrepareToDraw(_stat);
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    
    const double gap = 10;
    const double text_y_off = _start_y + g_TextInsetsInLine[1] + m_FontAscent;
    

    // Draw background
    NSRect footer_rect = NSMakeRect(0, _start_y + 1, _width, m_Height - 1);
    NSDrawWindowBackground(footer_rect);
    
    // Footer line separator.
    CGContextSetStrokeColorWithColor(context, g_HeaderStrokeColor);
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
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
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
    
    NSString *avail = [NSString stringWithFormat:@"%@ available", unitStringFromBytes(m_CurrentStat.avail_bytes, 0)];
    m_FreeSpace = [[NSAttributedString alloc] initWithString:avail
                                                  attributes:attr2];
}
