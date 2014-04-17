//
//  ModernPanelViewPresenationItemsFooter.cpp
//  Files
//
//  Created by Michael G. Kazakov on 13.04.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "ModernPanelViewPresentationItemsFooter.h"
#import "ModernPanelViewPresentation.h"
#import "FontExtras.h"
#import "PanelData.h"
#import "VFS.h"

static const double g_TextInsetsInLine[4] = {7, 1, 5, 1};

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

static NSString* FormHumanReadableBytesAndFiles(uint64_t _sz, int _total_files)
{
    // TODO: localization support
    NSString *postfix = _total_files > 1 ? @"files" : @"file";
    NSString *bytes = @"";
    
#define __1000_1(a) ( (a) % 1000lu )
#define __1000_2(a) __1000_1( (a)/1000lu )
#define __1000_3(a) __1000_1( (a)/1000000lu )
#define __1000_4(a) __1000_1( (a)/1000000000lu )
#define __1000_5(a) __1000_1( (a)/1000000000000lu )
    if(_sz < 1000lu)
        bytes = [NSString stringWithFormat:@"%llu", _sz];
    else if(_sz < 1000lu * 1000lu)
        bytes = [NSString stringWithFormat:@"%llu %03llu", __1000_2(_sz), __1000_1(_sz)];
    else if(_sz < 1000lu * 1000lu * 1000lu)
        bytes = [NSString stringWithFormat:@"%llu %03llu %03llu", __1000_3(_sz), __1000_2(_sz), __1000_1(_sz)];
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu)
        bytes = [NSString stringWithFormat:@"%llu %03llu %03llu %03llu", __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz)];
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu * 1000lu)
        bytes = [NSString stringWithFormat:@"%llu %03llu %03llu %03llu %03llu", __1000_5(_sz), __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz)];
#undef __1000_1
#undef __1000_2
#undef __1000_3
#undef __1000_4
#undef __1000_5
    
    return [NSString stringWithFormat:@"Selected %@ in %d %@", bytes, _total_files, postfix];
}

static NSString* FormHumanReadableDateTime(time_t _in)
{
    static NSDateFormatter *date_formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        date_formatter = [NSDateFormatter new];
        [date_formatter setLocale:[NSLocale currentLocale]];
        [date_formatter setDateStyle:NSDateFormatterMediumStyle];	// short date
        [date_formatter setTimeStyle:NSDateFormatterShortStyle];       // no time
    });
    
    return [date_formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:_in]];
}

static NSString *ComposeFooterFileNameForEntry(const VFSListingItem &_dirent)
{
    // output is a direct filename or symlink path in ->filename form
    if(!_dirent.IsSymlink())
        return ((__bridge NSString*) _dirent.CFName()).copy;
    else if(_dirent.Symlink() != 0) {
        NSString *link = [NSString stringWithUTF8String:_dirent.Symlink()];
        if(link != nil)
            return [@"->" stringByAppendingString:link];
    }
    return @""; // fallback case
}

void ModernPanelViewPresentationItemsFooter::SetFont(NSFont *_font)
{
    m_Font = _font;
    m_FontHeight = GetLineHeightForFont((__bridge CTFontRef)m_Font, &m_FontAscent);
    m_Height = m_FontHeight + g_TextInsetsInLine[1] + g_TextInsetsInLine[3] + 1; // + 1 + 1
    
    NSDictionary* attributes = [NSDictionary dictionaryWithObject:m_Font forKey:NSFontAttributeName];
    NSString *max_footer_datetime = [NSString stringWithFormat:@"%@A", FormHumanReadableDateTime(777600)];
    m_DateTimeWidth = ceil([max_footer_datetime sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
    
    m_SizeWidth = ceil([@"999999" sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
    
    // flush caches
    m_LastStatistics = PanelDataStatistics();
    m_LastItemName.clear();
}

void ModernPanelViewPresentationItemsFooter::Draw(const VFSListingItem* _current_entry,
                                                  const PanelDataStatistics &_stats,
                                                  PanelViewType _view_type,
                                                  bool _active,
                                                  double _start_y,
          double _width
          
          )
{
    PrepareToDraw(_current_entry, _stats, _view_type, _active);
    
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    
    const double gap = 10;
    const double text_y_off = _start_y + g_TextInsetsInLine[1] + m_FontAscent;
    
    // Footer gradient.
    CGContextSaveGState(context);
    NSRect footer_rect = NSMakeRect(0, _start_y + 1, _width, m_Height - 1);
    CGContextAddRect(context, footer_rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context,
                                _active ? ActiveTextGradient() : InactiveTextGradient(),
                                footer_rect.origin,
                                NSMakePoint(footer_rect.origin.x,
                                            footer_rect.origin.y + footer_rect.size.height),
                                0);
    CGContextRestoreGState(context);
    
    // Footer line separator.
    CGContextSetStrokeColorWithColor(context, g_HeaderStrokeColor);
    NSPoint footer_points[2] = { {0, _start_y + 0.5}, {_width, _start_y + 0.5} };
    CGContextStrokeLineSegments(context, footer_points, 2);
    
    // If any number of items are selected, then draw selection stats.
    // Otherwise, draw stats of cursor item.
    if(_stats.selected_entries_amount != 0)
    {
        [m_StatsStr drawWithRect:NSMakeRect(gap, text_y_off, _width - 2.*gap, m_FontHeight)
                         options:0];
    }
    else if(_current_entry != nullptr)
    {
        if (_view_type != PanelViewType::ViewFull)
        {
            [m_ItemDateStr drawWithRect:NSMakeRect(_width - gap - m_DateTimeWidth, text_y_off, m_DateTimeWidth, m_FontHeight)
                                options:0];
            [m_ItemSizeStr drawWithRect:NSMakeRect(_width - gap - m_DateTimeWidth - m_SizeWidth, text_y_off, m_SizeWidth, m_FontHeight)
                                options:0];
        }
        
        double name_width = _width - 2.*gap;
        if (_view_type != PanelViewType::ViewFull)
            name_width -= m_DateTimeWidth + m_SizeWidth;
        
        if(name_width > 0.)
            [m_ItemNameStr drawWithRect:NSMakeRect(gap, text_y_off, name_width, m_FontHeight)
                                options:0];
    }
}

void ModernPanelViewPresentationItemsFooter::PrepareToDraw(const VFSListingItem* _current_item, const PanelDataStatistics &_stats, PanelViewType _view_type, bool _active)
{
    if(_stats.selected_entries_amount != 0)
    {
        // should draw statistics info - check if current information is current
        if(m_LastStatistics == _stats && m_LastActive == _active)
            return; // ok, we're up to date
        
        // we're outdated, rebuild
        NSString *str = FormHumanReadableBytesAndFiles(_stats.bytes_in_selected_entries,
                                                       _stats.selected_entries_amount);

        NSMutableParagraphStyle *sel_items_footer_pstyle = [NSMutableParagraphStyle new];
        sel_items_footer_pstyle.alignment = NSCenterTextAlignment;
        sel_items_footer_pstyle.lineBreakMode = NSLineBreakByTruncatingHead;
        
        auto attr = @{NSFontAttributeName: m_Font,
                      NSParagraphStyleAttributeName: sel_items_footer_pstyle,
                      NSShadowAttributeName: (_active ? ActiveTextShadow() : InactiveTextShadow()) };
        
        m_StatsStr = [[NSAttributedString alloc] initWithString:str
                                                     attributes:attr];
     
        m_LastStatistics = _stats;
        m_LastActive = _active;
    }
    else if(_current_item != nullptr)
    {
        if(m_LastActive == _active &&
           m_LastItemName == _current_item->Name() &&
           m_LastItemSize == _current_item->Size() &&
           m_LastItemDate == _current_item->MTime() &&
           m_LastItemSymlink.empty() == !_current_item->IsSymlink() &&
           (!_current_item->IsSymlink() || m_LastItemSymlink == _current_item->Symlink()) &&
           m_LastItemIsDir == _current_item->IsDir() &&
           m_LastItemIsDotDot == _current_item->IsDotDot()
           )
            return; // ok, we're up to date
        
        // nope, we're outdated, need to rebuild info
        m_LastActive = _active;
        m_LastItemName = _current_item->Name();
        m_LastItemSize = _current_item->Size();
        m_LastItemDate = _current_item->MTime();
        m_LastItemIsDir = _current_item->IsDir();
        m_LastItemIsDotDot = _current_item->IsDotDot();
        if(_current_item->IsSymlink())
            m_LastItemSymlink = _current_item->Symlink();
        else
            m_LastItemSymlink.clear();
        
        static NSMutableParagraphStyle *par1, *par2;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            par1 = [NSMutableParagraphStyle new];
            par1.alignment = NSRightTextAlignment;
            par1.lineBreakMode = NSLineBreakByClipping;
            par2 = [NSMutableParagraphStyle new];
            par2.alignment = NSLeftTextAlignment;
            par2.lineBreakMode = NSLineBreakByTruncatingHead;
        });
        
        NSDictionary *attr1 = @{NSFontAttributeName:m_Font,
                                NSParagraphStyleAttributeName:par1,
                                NSShadowAttributeName:(_active ? ActiveTextShadow() : InactiveTextShadow())};
        NSDictionary *attr2 = @{NSFontAttributeName:m_Font,
                                NSParagraphStyleAttributeName: par2,
                                NSShadowAttributeName:(_active ? ActiveTextShadow() : InactiveTextShadow())};

        NSString *date_str = FormHumanReadableDateTime(m_LastItemDate);
        m_ItemDateStr = [[NSAttributedString alloc] initWithString:date_str
                                                        attributes:attr1];
        
        NSString *size_str = ModernPanelViewPresentation::SizeToString6(*_current_item);
        m_ItemSizeStr = [[NSAttributedString alloc] initWithString:size_str
                                                        attributes:attr1];

        NSString *file_str = ComposeFooterFileNameForEntry(*_current_item);
        m_ItemNameStr = [[NSAttributedString alloc] initWithString:file_str
                                                        attributes:attr2];
        
        // check if current info about date-time string is invalid
        double date_str_width = m_ItemDateStr.size.width;
        if(date_str_width + g_TextInsetsInLine[0] + g_TextInsetsInLine[2] > m_DateTimeWidth)
            m_DateTimeWidth = ceil(date_str_width + g_TextInsetsInLine[0] + g_TextInsetsInLine[2]);
    }
}
