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
#import "ByteCountFormatter.h"

static const double g_TextInsetsInLine[4] = {7, 1, 5, 1};
static CGColorRef g_FooterStrokeColorAct = CGColorCreateGenericRGB(176/255.0, 176/255.0, 176/255.0, 1.0);
static CGColorRef g_FooterStrokeColorInact = CGColorCreateGenericRGB(225/255.0, 225/255.0, 225/255.0, 1.0);

static NSString* FormHumanReadableBytesAndFiles(uint64_t _sz, int _total_files)
{
    // TODO: localization support
    NSString *postfix = _total_files > 1 ? @"files" : @"file";
    return [NSString stringWithFormat:@"Selected %@ bytes in %d %@",
                    ByteCountFormatter::Instance().SpaceSeparated_NSString(_sz),
                    _total_files,
                    postfix];
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
        return (_dirent.NSName()).copy;
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
                                                  bool _wnd_active,                                                  
                                                  double _start_y,
          double _width
          
          )
{
    if(!_wnd_active)
        _active = false;
    
    PrepareToDraw(_current_entry, _stats, _view_type, _active);
    
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    
    const double gap = 10;
    const double text_y_off = _start_y + g_TextInsetsInLine[1] + m_FontAscent;
    
    // Footer bg.
    CGContextSaveGState(context);
    NSRect footer_rect = NSMakeRect(0, _start_y + 1, _width, m_Height - 1);
    if(_active) {
        static CGColorRef bg = CGColorCreateGenericRGB(1, 1, 1, 1);
        CGContextSetFillColorWithColor(context, bg);
        CGContextFillRect(context, footer_rect);
    }
    else
        NSDrawWindowBackground(footer_rect);
    CGContextRestoreGState(context);
    
    // Footer line separator.
    CGContextSetStrokeColorWithColor(context, _wnd_active ? g_FooterStrokeColorAct : g_FooterStrokeColorInact);
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
                      NSParagraphStyleAttributeName: sel_items_footer_pstyle};
        
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
                                NSParagraphStyleAttributeName:par1};
        NSDictionary *attr2 = @{NSFontAttributeName:m_Font,
                                NSParagraphStyleAttributeName: par2};

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
