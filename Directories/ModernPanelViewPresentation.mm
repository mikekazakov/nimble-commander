//
//  ModernPanelViewPresentation.cpp
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//


#import "ModernPanelViewPresentation.h"
#import "ModernPanelViewPresentationIconCache.h"
#import "PanelData.h"
#import "Encodings.h"
#import "Common.h"
#import "NSUserDefaults+myColorSupport.h"
#import "FontExtras.h"

#import <deque>
#import <pthread.h>


static void FormHumanReadableBytesAndFiles(unsigned long _sz, int _total_files, UniChar _out[128], size_t &_symbs)
{
    // TODO: localization support
    char buf[128] = {0};
    const char *postfix = _total_files > 1 ? "files" : "file";
#define __1000_1(a) ( (a) % 1000lu )
#define __1000_2(a) __1000_1( (a)/1000lu )
#define __1000_3(a) __1000_1( (a)/1000000lu )
#define __1000_4(a) __1000_1( (a)/1000000000lu )
#define __1000_5(a) __1000_1( (a)/1000000000000lu )
    if(_sz < 1000lu)
        sprintf(buf, "Selected %lu bytes in %d %s", _sz, _total_files, postfix);
    else if(_sz < 1000lu * 1000lu)
        sprintf(buf, "Selected %lu %03lu bytes in %d %s", __1000_2(_sz), __1000_1(_sz), _total_files, postfix);
    else if(_sz < 1000lu * 1000lu * 1000lu)
        sprintf(buf, "Selected %lu %03lu %03lu bytes in %d %s", __1000_3(_sz), __1000_2(_sz), __1000_1(_sz), _total_files, postfix);
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu)
        sprintf(buf, "Selected %lu %03lu %03lu %03lu bytes in %d %s", __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz), _total_files, postfix);
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu * 1000lu)
        sprintf(buf, "Selected %lu %03lu %03lu %03lu %03lu bytes in %d %s", __1000_5(_sz), __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz), _total_files, postfix);
#undef __1000_1
#undef __1000_2
#undef __1000_3
#undef __1000_4
#undef __1000_5
    
    _symbs = strlen(buf);
    for(int i = 0; i < _symbs; ++i) _out[i] = buf[i];
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

static NSString* FormHumanReadableShortDate(time_t _in)
{
    static NSDateFormatter *date_formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        date_formatter = [NSDateFormatter new];
        [date_formatter setLocale:[NSLocale currentLocale]];
        [date_formatter setDateStyle:NSDateFormatterShortStyle];	// short date
        [date_formatter setTimeStyle:NSDateFormatterNoStyle];       // no time
    });
    
    return [date_formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:_in]];
}

static NSString* FormHumanReadableShortTime(time_t _in)
{
    static NSDateFormatter *date_formatter = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        date_formatter = [NSDateFormatter new];
        [date_formatter setLocale:[NSLocale currentLocale]];
        [date_formatter setDateStyle:NSDateFormatterNoStyle];       // no date
        [date_formatter setTimeStyle:NSDateFormatterShortStyle];    // short time
    });
    
    return [date_formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:_in]];
}

// _out will be _not_ null-terminated, just a raw buffer
static void FormHumanReadableSizeRepresentation6(unsigned long _sz, UniChar _out[6])
{
    char buf[32];
    
    if(_sz < 1000000) // bytes
    {
        sprintf(buf, "%6ld", _sz);
    }
    else if(_sz < 9999lu * 1024lu) // kilobytes
    {
        unsigned long div = 1024lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld K", res + (_sz - res * div) / (div/2));
    }
    else if(_sz < 9999lu * 1048576lu) // megabytes
    {
        unsigned long div = 1048576lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld M", res + (_sz - res * div) / (div/2));
    }
    else if(_sz < 9999lu * 1073741824lu) // gigabytes
    {
        unsigned long div = 1073741824lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld G", res + (_sz - res * div) / (div/2));
    }
    else if(_sz < 9999lu * 1099511627776lu) // terabytes
    {
        unsigned long div = 1099511627776lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld T", res + (_sz - res * div) / (div/2));
    }
    else if(_sz < 9999lu * 1125899906842624lu) // petabytes
    {
        unsigned long div = 1125899906842624lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%4ld P", res + (_sz - res * div) / (div/2));
    }
    else memset(buf, 0, 32);
    
    for(int i = 0; i < 6; ++i) _out[i] = buf[i];
}

static void FormHumanReadableSizeReprentationForDirEnt6(const DirectoryEntryInformation *_dirent, UniChar _out[6])
{
    if( _dirent->isdir() )
    {
        if( _dirent->size != DIRENTINFO_INVALIDSIZE)
        {
            FormHumanReadableSizeRepresentation6(_dirent->size, _out); // this code will be used some day when F3 will be implemented
        }
        else
        {
            char buf[32];
            memset(buf, 0, sizeof(buf));
            
            if( !_dirent->isdotdot()) strcpy(buf, "Folder");
            else                      strcpy(buf, "    Up");
            
            for(int i = 0; i < 6; ++i) _out[i] = buf[i];
        }
    }
    else
    {
        FormHumanReadableSizeRepresentation6(_dirent->size, _out);
    }
}

static void ComposeFooterFileNameForEntry(const DirectoryEntryInformation &_dirent, UniChar _buff[256], size_t &_sz)
{   // output is a direct filename or symlink path in ->filename form
    if(!_dirent.issymlink())
    {
        InterpretUTF8BufferAsUniChar( _dirent.name(), _dirent.namelen, _buff, &_sz, 0xFFFD);
    }
    else
    {
        if(_dirent.symlink != 0)
        {
            _buff[0]='-';
            _buff[1]='>';
            InterpretUTF8BufferAsUniChar( (unsigned char*)_dirent.symlink, strlen(_dirent.symlink), _buff+2, &_sz, 0xFFFD);
            _sz += 2;
        }
        else
        {
            _sz = 0; // fallback case
        }
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// class ModernPanelViewPresentation
///////////////////////////////////////////////////////////////////////////////////////////////////

// Item name display insets inside the item line.
// Order: left, top, right, bottom.
const int g_TextInsetsInLine[4] = {7, 0, 5, 1}; // TODO: remove this black magic
// Width of the divider between views.
const int g_DividerWidth = 3;

ModernPanelViewPresentation::ModernPanelViewPresentation()
{
    m_Size.width = m_Size.height = 0;
 
    BuildGeometry();
    BuildAppearance();
    
    // build icon cache regarding current font size (icon size equals font height)
    m_IconCache = new ModernPanelViewPresentationIconCache(this, m_FontHeight);
    m_IconCache->SetIconMode((int)[[NSUserDefaults standardUserDefaults] integerForKey:@"ModernSkinIconMode"]);
    
    // Init active header and footer gradient.
    {
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        const CGFloat outer_color[3] = { 200/255.0, 230/255.0, 245/255.0 };
        const CGFloat inner_color[3] = { 130/255.0, 196/255.0, 240/255.0 };
        CGFloat components[] =
        {
            outer_color[0], outer_color[1], outer_color[2], 1.0,
            inner_color[0], inner_color[1], inner_color[2], 1.0,
            inner_color[0], inner_color[1], inner_color[2], 1.0,
            outer_color[0], outer_color[1], outer_color[2], 1.0
        };
        CGFloat locations[] = {0.0, 0.45, 0.55, 1.0};
        m_ActiveHeaderGradient = CGGradientCreateWithColorComponents(color_space, components, locations, 4);
        CGColorSpaceRelease(color_space);
    }
    
    // Init inactive header and footer gradient.
    {
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
        m_InactiveHeaderGradient = CGGradientCreateWithColorComponents(color_space, components, locations, 4);
        CGColorSpaceRelease(color_space);
    }
}

ModernPanelViewPresentation::~ModernPanelViewPresentation()
{
    CGGradientRelease(m_ActiveHeaderGradient);
    CGGradientRelease(m_InactiveHeaderGradient);
    
    assert(m_IconCache);
    delete m_IconCache;

    if(m_State->Data != 0)
        m_State->Data->CustomIconClearAll();
}

void ModernPanelViewPresentation::BuildGeometry()
{    
    // build font geometry according current settings
    m_Font = [[NSUserDefaults standardUserDefaults] fontForKey:@"FilePanelsModernFont"];
    if(!m_Font) m_Font = [NSFont fontWithName:@"Lucida Grande" size:13];
    
    // Height of a single file line calculated from the font.
    m_FontHeight = int(GetLineHeightForFont((__bridge CTFontRef)m_Font));
    m_LineHeight = m_FontHeight + 2; // was 18 before (16 + 2)
    
    NSDictionary* attributes = [NSDictionary dictionaryWithObject:m_Font forKey:NSFontAttributeName];
    
    m_SizeColumWidth = (int)ceil([@"999999" sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
    
    // 9 days after 1970
    m_DateColumnWidth = (int)ceil([FormHumanReadableShortDate(777600) sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
    m_TimeColumnWidth = (int)ceil([FormHumanReadableShortTime(777600) sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
    NSString *max_footer_datetime = [NSString stringWithFormat:@"%@A", FormHumanReadableDateTime(777600)];
    m_DateTimeFooterWidth = (int)ceil([max_footer_datetime sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
}

void ModernPanelViewPresentation::BuildAppearance()
{
    // Active header and footer text shadow.
    m_ActiveHeaderTextShadow = [NSShadow new];
    m_ActiveHeaderTextShadow.shadowBlurRadius = 1;
    m_ActiveHeaderTextShadow.shadowColor = [NSColor colorWithDeviceRed:0.83 green:0.93 blue:1 alpha:1];
    m_ActiveHeaderTextShadow.shadowOffset = NSMakeSize(0, -1);
    
    // Inactive header and footer text shadow.
    m_InactiveHeaderTextShadow = [[NSShadow alloc] init];
    m_InactiveHeaderTextShadow.shadowBlurRadius = 1;
    m_InactiveHeaderTextShadow.shadowColor = [NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:0.9];
    m_InactiveHeaderTextShadow.shadowOffset = NSMakeSize(0, -1);    
    
    NSMutableParagraphStyle *item_text_pstyle = [NSMutableParagraphStyle new];
    item_text_pstyle.alignment = NSLeftTextAlignment;
    item_text_pstyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    
    m_ActiveSelectedItemTextAttr =
    @{
      NSFontAttributeName: m_Font,
      NSForegroundColorAttributeName: [NSColor whiteColor], // TODO: color selection
      NSParagraphStyleAttributeName: item_text_pstyle
      };
    
    m_ItemTextAttr =
    @{
      NSFontAttributeName: m_Font,
      NSForegroundColorAttributeName: [NSColor blackColor], // TODO: color selection
      NSParagraphStyleAttributeName: item_text_pstyle
      };
    
    NSMutableParagraphStyle *size_col_text_pstyle = [NSMutableParagraphStyle new];
    size_col_text_pstyle.alignment = NSRightTextAlignment;
    size_col_text_pstyle.lineBreakMode = NSLineBreakByClipping;
    
    m_ActiveSelectedSizeColumnTextAttr =
    @{NSFontAttributeName: m_Font,
      NSForegroundColorAttributeName: [NSColor whiteColor],
      NSParagraphStyleAttributeName: size_col_text_pstyle
      };

    m_SizeColumnTextAttr =
    @{NSFontAttributeName: m_Font,
      NSForegroundColorAttributeName: [NSColor blackColor],
      NSParagraphStyleAttributeName: size_col_text_pstyle
      };
    
    NSMutableParagraphStyle *sel_items_footer_pstyle = [NSMutableParagraphStyle new];
    sel_items_footer_pstyle.alignment = NSCenterTextAlignment;
    sel_items_footer_pstyle.lineBreakMode = NSLineBreakByTruncatingHead;
    
    m_SelectedItemsFooterTextAttr = @{NSFontAttributeName: m_Font,
                                       NSParagraphStyleAttributeName: sel_items_footer_pstyle,
                                       NSShadowAttributeName: m_InactiveHeaderTextShadow};
    
    m_ActiveSelectedItemsFooterTextAttr = @{NSFontAttributeName: m_Font,
                                      NSParagraphStyleAttributeName: sel_items_footer_pstyle,
                                      NSShadowAttributeName: m_ActiveHeaderTextShadow};
}

void ModernPanelViewPresentation::Draw(NSRect _dirty_rect)
{
    if (!m_State || !m_State->Data) return;
    assert(m_State->CursorPos < (int)m_State->Data->SortedDirectoryEntries().size());
    assert(m_State->ItemsDisplayOffset >= 0);
    
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    auto &entries = m_State->Data->DirectoryEntries();
    const int items_per_column = GetMaxItemsPerColumn();
    const int max_items = (int)sorted_entries.size();
    const int columns_count = GetNumberOfItemColumns();
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Prepare icons for
    bool created_icons = false;
    int count = 0, total_count = items_per_column*columns_count;
    int i = m_State->ItemsDisplayOffset;
    for(; count < total_count && i < max_items; ++count, ++i)
    {
        int raw_index = sorted_entries[i];
        const DirectoryEntryInformation &entry = entries[raw_index];
        if (entry.cicon == 0)
        {
            created_icons = true;
            m_IconCache->CreateIcon(entry, raw_index, m_State->Data);
        }
    }
    
    if (created_icons && m_IconCache->IsNeedsLoading())
        m_IconCache->RunLoadThread(m_State->Data);
    
    ///////////////////////////////////////////////////////////////////////////////
    // Clear view background.
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, NSRectToCGRect(_dirty_rect));
    
    ///////////////////////////////////////////////////////////////////////////////
    // Divider.
    static CGColorRef divider_stroke_color = CGColorCreateGenericRGB(101/255.0, 101/255.0, 101/255.0, 1.0);
    static CGColorRef divider_fill_color = CGColorCreateGenericRGB(174/255.0, 174/255.0, 174/255.0, 1.0);
    
    CGContextSetStrokeColorWithColor(context, divider_stroke_color);
    if (m_IsLeft)
    {
        float x = m_ItemsArea.origin.x + m_ItemsArea.size.width;
        NSPoint view_divider[2] = {
            NSMakePoint(x + 0.5, 0), NSMakePoint(x + 0.5, m_Size.height)
        };
        CGContextStrokeLineSegments(context, view_divider, 2);
        
        
        CGContextSetFillColorWithColor(context, divider_fill_color);
        CGContextFillRect(context, NSMakeRect(x + 1, 0, g_DividerWidth - 1, m_Size.height));
    }
    else
    {
        NSPoint view_divider[2] = {
            NSMakePoint(g_DividerWidth - 0.5, 0), NSMakePoint(g_DividerWidth - 0.5, m_Size.height)
        };
        CGContextStrokeLineSegments(context, view_divider, 2);
        
        
        CGContextSetFillColorWithColor(context, divider_fill_color);
        CGContextFillRect(context, NSMakeRect(0, 0, g_DividerWidth - 1, m_Size.height));
    }

    // If current panel is on the right, then translate all rendering by the divider's width.
    if (!m_IsLeft) CGContextTranslateCTM(context, g_DividerWidth, 0);
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Header and footer.
    CGColorRef header_stroke_color = CGColorCreateGenericRGB(102/255.0, 102/255.0, 102/255.0, 1.0);
    int header_height = m_ItemsArea.origin.y;
    
    NSShadow *header_text_shadow = m_ActiveHeaderTextShadow;
    if (!m_State->Active) header_text_shadow = m_InactiveHeaderTextShadow;
    
    CGGradientRef header_gradient = m_ActiveHeaderGradient;
    if (!m_State->Active) header_gradient = m_InactiveHeaderGradient;
    
    // Header gradient.
    CGContextSaveGState(context);
    NSRect header_rect = NSMakeRect(0, 0, m_ItemsArea.size.width, header_height - 1);
    CGContextAddRect(context, header_rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, header_gradient, header_rect.origin,
                                NSMakePoint(header_rect.origin.x,
                                            header_rect.origin.y + header_rect.size.height), 0);
    CGContextRestoreGState(context);
    
    // Header line separator.
    CGContextSetStrokeColorWithColor(context, header_stroke_color);
    NSPoint header_points[2] = {
        NSMakePoint(0, header_height - 0.5), NSMakePoint(m_ItemsArea.size.width, header_height - 0.5)
    };
    CGContextStrokeLineSegments(context, header_points, 2);
    
    // Panel path.
    char panelpath[__DARWIN_MAXPATHLEN] = {0};
    m_State->Data->GetDirectoryPathWithTrailingSlash(panelpath);
    NSString *header_string = [NSString stringWithUTF8String:panelpath];
    
    int delta = (header_height - m_LineHeight)/2;
    NSRect rect = NSMakeRect(20, delta, m_ItemsArea.size.width - 40, m_LineHeight);
    
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
    
    static const NSMutableParagraphStyle *header_text_pstyle = ^{
        NSMutableParagraphStyle *p = [[NSMutableParagraphStyle alloc] init];
        p.alignment = NSCenterTextAlignment;
        p.lineBreakMode = NSLineBreakByTruncatingHead;
        return p;
    }();
    
    NSDictionary *header_text_attr =@{NSFontAttributeName: m_Font,
                                      NSParagraphStyleAttributeName: header_text_pstyle,
                                      NSShadowAttributeName: header_text_shadow};
    
    [header_string drawWithRect:rect options:options attributes:header_text_attr];
    
    // Footer
    const int footer_y = m_ItemsArea.origin.y + m_ItemsArea.size.height;
    
    // Footer gradient.
    CGContextSaveGState(context);
    NSRect footer_rect = NSMakeRect(0, footer_y + 1, m_ItemsArea.size.width, header_height - 1);
    CGContextAddRect(context, footer_rect);
    CGContextClip(context);
    CGContextDrawLinearGradient(context, header_gradient, footer_rect.origin,
                                NSMakePoint(footer_rect.origin.x,
                                            footer_rect.origin.y + footer_rect.size.height), 0);
    CGContextRestoreGState(context);
    
    // Footer line separator.
    CGContextSetStrokeColorWithColor(context, header_stroke_color);
    NSPoint footer_points[2] = {
        NSMakePoint(0, footer_y + 0.5), NSMakePoint(m_ItemsArea.size.width, footer_y + 0.5)
    };
    CGContextStrokeLineSegments(context, footer_points, 2);
    
    // Footer string.
    // If any number of items are selected, then draw selection stats.
    // Otherwise, draw stats of cursor item.
    if(m_State->Data->GetSelectedItemsCount() != 0)
    {
        UniChar selectionbuf[512];
        size_t sz;
        FormHumanReadableBytesAndFiles(m_State->Data->GetSelectedItemsSizeBytes(),
                                       m_State->Data->GetSelectedItemsCount(), selectionbuf, sz);
        
        const int delta = (header_height - m_LineHeight)/2;
        const int offset = 10;
        
        NSString *sel_str = [NSString stringWithCharacters:selectionbuf length:sz];
        [sel_str drawWithRect:NSMakeRect(offset, footer_y + delta,
                                         m_ItemsArea.size.width - 2*offset, m_LineHeight)
                      options:NSStringDrawingUsesLineFragmentOrigin
                   attributes:m_State->Active?m_ActiveSelectedItemsFooterTextAttr:m_SelectedItemsFooterTextAttr];
    }
    else if(m_State->CursorPos >= 0)
    {
        UniChar buff[256];
        size_t buf_size = 0;
        const DirectoryEntryInformation *current_entry = &entries[sorted_entries[m_State->CursorPos]];

        const int delta = (header_height - m_LineHeight)/2;
        const int offset = 10;

        NSDictionary *footer_text_attr;
        
        if (m_State->ViewType != PanelViewType::ViewFull)
        {
            static const NSMutableParagraphStyle *pstyle = ^{
                NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
                p.alignment = NSRightTextAlignment;
                p.lineBreakMode = NSLineBreakByClipping;
                return p;
            } ();
            
            footer_text_attr = @{NSFontAttributeName: m_Font,
                                 NSParagraphStyleAttributeName:pstyle,
                                 NSShadowAttributeName: header_text_shadow};
            
            NSString *time_str = FormHumanReadableDateTime(current_entry->mtime);
            [time_str drawWithRect:NSMakeRect(m_ItemsArea.size.width - offset - m_DateTimeFooterWidth,
                                              footer_y + delta,
                                              m_DateTimeFooterWidth, m_LineHeight)
                           options:NSStringDrawingUsesLineFragmentOrigin
                        attributes:footer_text_attr];
            
            UniChar size_info[6];
            FormHumanReadableSizeReprentationForDirEnt6(current_entry, size_info);
            NSString *size_str = [[NSString alloc] initWithCharactersNoCopy:size_info length:6 freeWhenDone:false];
            [size_str drawWithRect:NSMakeRect(m_ItemsArea.size.width - offset - m_DateTimeFooterWidth - m_SizeColumWidth,
                                              footer_y + delta,
                                              m_SizeColumWidth, m_LineHeight)
                           options:NSStringDrawingUsesLineFragmentOrigin
                        attributes:footer_text_attr];
        }
        
        static const NSMutableParagraphStyle *footer_text_pstyle = (NSMutableParagraphStyle *)^{
            NSMutableParagraphStyle *p = [NSMutableParagraphStyle new];
            p.alignment = NSLeftTextAlignment;
            p.lineBreakMode = NSLineBreakByTruncatingHead;
            return p;
        } ();
        
        footer_text_attr = @{NSFontAttributeName: m_Font,
                             NSParagraphStyleAttributeName: footer_text_pstyle,
                             NSShadowAttributeName: header_text_shadow};
        
        int name_width = m_ItemsArea.size.width - 2*offset;
        if (m_State->ViewType != PanelViewType::ViewFull)
            name_width -= m_DateTimeFooterWidth + m_SizeColumWidth;
        ComposeFooterFileNameForEntry(*current_entry, buff, buf_size);
        NSString *name_str = [NSString stringWithCharacters:buff length:buf_size];
        [name_str drawWithRect:NSMakeRect(offset, footer_y + delta, name_width, m_LineHeight) options:options attributes:footer_text_attr];
    }
    
    CGColorRelease(header_stroke_color);
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Draw items in columns.    
    CGColorRef active_selected_item_back = CGColorCreateGenericRGB(43/255.0, 116/255.0, 211/255.0, 1.0);
    CGColorRef inactive_selected_item_back = CGColorCreateGenericRGB(212/255.0, 212/255.0, 212/255.0, 1.0);
    CGColorRef active_cursor_item_back = CGColorCreateGenericRGB(130/255.0, 196/255.0, 240/255.0, 1.0);
    CGColorRef column_divider_color = CGColorCreateGenericRGB(224/255.0, 224/255.0, 224/255.0, 1.0);
    CGColorRef cursor_frame_color = CGColorCreateGenericRGB(0, 0, 0, 1);
    CGColorRef item_back = CGColorCreateGenericRGB(240/255.0, 245/255.0, 250/255.0, 1);
    
    const int icon_size = m_FontHeight;
    const int start_y = m_ItemsArea.origin.y;
        
    for (int column = 0; column < columns_count; ++column)
    {
        // Draw column.
        int column_width = int(m_ItemsArea.size.width - (columns_count - 1))/columns_count;
        // Calculate index of the first item in current column.
        int i = m_State->ItemsDisplayOffset + column*items_per_column;
        // X position of items.
        int start_x = column*(column_width + 1);
        
        if (column == columns_count - 1)
            column_width += int(m_ItemsArea.size.width - (columns_count - 1))%columns_count;
        
        // Draw column divider.
        if (column < columns_count - 1)
        {
            NSPoint points[2] = {
                NSMakePoint(start_x + 0.5 + column_width, start_y),
                NSMakePoint(start_x + 0.5 + column_width, start_y + m_ItemsArea.size.height)
            };
            CGContextSetStrokeColorWithColor(context, column_divider_color);
            CGContextSetLineWidth(context, 1);
            CGContextStrokeLineSegments(context, points, 2);
        }
        
        int count = 0;
        for (; count < items_per_column; ++count, ++i)
        {
            const DirectoryEntryInformation *item = nullptr;
            auto raw_index = 0;
            
            if (i < max_items)
            {
                raw_index = sorted_entries[i];
                item = &entries[raw_index];
            }
            
            NSRect rect = NSMakeRect(start_x + icon_size + 2*g_TextInsetsInLine[0],
                                     start_y + count*m_LineHeight + g_TextInsetsInLine[1],
                                     column_width - icon_size - 2*g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                     m_LineHeight - g_TextInsetsInLine[1] - g_TextInsetsInLine[3]);
            
            NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
            
            NSDictionary *cur_item_text_attr = m_ItemTextAttr;
            if (m_State->Active && item && item->cf_isselected())
                cur_item_text_attr = m_ActiveSelectedItemTextAttr;
            
            // Draw background.
            if (item && item->cf_isselected())
            {
                // Draw selected item.
                if (m_State->Active)
                {
                    int offset = 1;
                    if (m_State->CursorPos == i && m_State->Active) offset = 2;
                    CGContextSetFillColorWithColor(context, active_selected_item_back);
                    CGContextFillRect(context, NSMakeRect(start_x + offset,
                                                          start_y + count*m_LineHeight + offset,
                                                          column_width - 2*offset,
                                                          m_LineHeight - 2*offset + 1));
                }
                else
                {
                    CGContextSetFillColorWithColor(context, inactive_selected_item_back);
                    CGContextFillRect(context, NSMakeRect(start_x + 1,
                                                          start_y + count*m_LineHeight + 1,
                                                          column_width - 2, m_LineHeight - 1));
                }
            }
            else if (count % 2 == 1)
            {
                CGContextSetFillColorWithColor(context, item_back);
                CGContextFillRect(context, NSMakeRect(start_x + 1, start_y + count*m_LineHeight + 1,
                                                      column_width - 2, m_LineHeight - 1));
            }
            
            if (!item) continue;
            
            // Draw cursor.
            if (m_State->CursorPos == i && m_State->Active)
            {
                // Draw as cursor item (only if panel is active).
                CGContextSaveGState(context);
                CGFloat dashes[2] = { 2, 4 };
                CGContextSetLineDash(context, 0, dashes, 2);
                CGContextSetStrokeColorWithColor(context, cursor_frame_color);
                CGContextStrokeRect(context, NSMakeRect(start_x + 1.5,
                                                        start_y + count*m_LineHeight + 1.5,
                                                        column_width - 3, m_LineHeight - 2));
                CGContextRestoreGState(context);
            }
            
            // Draw stats columns for specific views.
            int spec_col_x = m_ItemsArea.size.width;
            if (m_State->ViewType == PanelViewType::ViewFull)
            {
                NSRect time_rect = NSMakeRect(spec_col_x - m_TimeColumnWidth + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              m_TimeColumnWidth - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);
                
                NSString *time_str = FormHumanReadableShortTime(item->mtime);
                [time_str drawWithRect:time_rect options:options attributes:cur_item_text_attr];
                
                rect.size.width -= m_TimeColumnWidth;
                spec_col_x -= m_TimeColumnWidth;
                
                NSRect date_rect = NSMakeRect(spec_col_x - m_DateColumnWidth + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              m_DateColumnWidth - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);
                NSString *date_str = FormHumanReadableShortDate(item->mtime);
                [date_str drawWithRect:date_rect options:options attributes:cur_item_text_attr];
                
                rect.size.width -= m_DateColumnWidth;
                spec_col_x -= m_DateColumnWidth;
            }
            if(m_State->ViewType == PanelViewType::ViewWide
               || m_State->ViewType == PanelViewType::ViewFull)
            {
                // draw the entry size on the right
                NSRect size_rect = NSMakeRect(spec_col_x - m_SizeColumWidth + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              m_SizeColumWidth - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);

                UniChar size_info[6];
                FormHumanReadableSizeReprentationForDirEnt6(item, size_info);
                NSString *size_str = [[NSString alloc] initWithCharactersNoCopy:size_info length:6 freeWhenDone:false];
                [size_str drawWithRect:size_rect
                               options:options
                            attributes:m_State->Active && item->cf_isselected() ? m_ActiveSelectedSizeColumnTextAttr : m_SizeColumnTextAttr];
                
                rect.size.width -= m_SizeColumWidth;
            }
            
            // Draw item text.
            [(__bridge NSString *)item->cf_name drawWithRect:rect options:options attributes:cur_item_text_attr];

            // Draw icon
            NSImageRep *image_rep = m_IconCache->GetIcon(*item);
            NSRect icon_rect = NSMakeRect(start_x + g_TextInsetsInLine[0],
                                     start_y + count*m_LineHeight + m_LineHeight - icon_size - 1,
                                     icon_size, icon_size);
            [image_rep drawInRect:icon_rect fromRect:NSZeroRect operation:NSCompositeSourceOver
                         fraction:1.0 respectFlipped:YES hints:nil];
        }
    }
    
    // Draw column dividers for specific views.
    if (m_State->ViewType == PanelViewType::ViewWide)
    {
        int x = m_ItemsArea.size.width - m_SizeColumWidth;
        NSPoint points[2] = {
            NSMakePoint(x + 0.5, start_y),
            NSMakePoint(x + 0.5, start_y + m_ItemsArea.size.height)
        };
        CGContextSetStrokeColorWithColor(context, column_divider_color);
        CGContextSetLineWidth(context, 1);
        CGContextStrokeLineSegments(context, points, 2);
    }
    else if (m_State->ViewType == PanelViewType::ViewFull)
    {
        int x_pos[3];
        x_pos[0] = m_ItemsArea.size.width - m_TimeColumnWidth;
        x_pos[1] = x_pos[0] - m_DateColumnWidth;
        x_pos[2] = x_pos[1] - m_SizeColumWidth;
        for (int i = 0; i < 3; ++i)
        {
            int x = x_pos[i];
            NSPoint points[2] = {
                NSMakePoint(x + 0.5, start_y),
                NSMakePoint(x + 0.5, start_y + m_ItemsArea.size.height)
            };
            CGContextSetStrokeColorWithColor(context, column_divider_color);
            CGContextSetLineWidth(context, 1);
            CGContextStrokeLineSegments(context, points, 2);
        }
    }
    
    CGColorRelease(active_selected_item_back);
    CGColorRelease(inactive_selected_item_back);
    CGColorRelease(active_cursor_item_back);
    CGColorRelease(column_divider_color);
    CGColorRelease(cursor_frame_color);
    CGColorRelease(item_back);
}

void ModernPanelViewPresentation::OnFrameChanged(NSRect _frame)
{
    m_Size = _frame.size;
    
    m_IsLeft = _frame.origin.x < 50;

    // Header and footer have the same height.
    const int header_height = m_LineHeight + 1;
    
    m_ItemsArea.origin.x = 0;
    m_ItemsArea.origin.y = header_height;
    m_ItemsArea.size.height = m_Size.height - 2*header_height;
    m_ItemsArea.size.width = m_Size.width - g_DividerWidth;
    if (!m_IsLeft) m_ItemsArea.origin.x += g_DividerWidth;
    
    m_ItemsPerColumn = int(m_ItemsArea.size.height/m_LineHeight);
    
    EnsureCursorIsVisible();
}

NSRect ModernPanelViewPresentation::GetItemColumnsRect()
{
    return m_ItemsArea;
}

int ModernPanelViewPresentation::GetItemIndexByPointInView(CGPoint _point)
{
    const int columns = GetNumberOfItemColumns();
    const int entries_in_column = GetMaxItemsPerColumn();
    
    NSRect items_rect = GetItemColumnsRect();
    
    // Check if click is in files' view area, including horizontal bottom line.
    if (!NSPointInRect(_point, items_rect)) return -1;
    
    // Calculate the number of visible files.
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    const int max_files_to_show = entries_in_column * columns;
    int visible_files = (int)sorted_entries.size() - m_State->ItemsDisplayOffset;
    if (visible_files > max_files_to_show) visible_files = max_files_to_show;
    
    // Calculate width of column.
    const int column_width = items_rect.size.width / columns;
    
    // Calculate cursor pos.
    int column = int(_point.x/column_width);
    int row = int((_point.y - items_rect.origin.y)/m_LineHeight);
    if (row >= entries_in_column) row = entries_in_column - 1;
    int file_number =  row + column*entries_in_column;
    if (file_number >= visible_files) file_number = visible_files - 1;
    
    return m_State->ItemsDisplayOffset + file_number;
}

int ModernPanelViewPresentation::GetNumberOfItemColumns()
{
    switch(m_State->ViewType)
    {
        case PanelViewType::ViewShort: return 3;
        case PanelViewType::ViewMedium: return 2;
        case PanelViewType::ViewWide: return 1;
        case PanelViewType::ViewFull: return 1;
    }
    assert(0);
    return 0;
}

int ModernPanelViewPresentation::GetMaxItemsPerColumn()
{
    return m_ItemsPerColumn;
}

void ModernPanelViewPresentation::OnSkinSettingsChanged()
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int icon_mode = (int)[defaults integerForKey:@"ModernSkinIconMode"];
    m_IconCache->SetIconMode(icon_mode);
    
    m_State->Data->CustomIconClearAll();
    
    SetViewNeedsDisplay();
}

void ModernPanelViewPresentation::UpdatePanelFrames(PanelView *_left, PanelView *_right, NSSize _size)
{
}

void ModernPanelViewPresentation::OnDirectoryChanged()
{
    m_IconCache->OnDirectoryChanged(m_State->Data);
}
