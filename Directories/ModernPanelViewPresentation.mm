//
//  ModernPanelViewPresentation.cpp
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//


#import "ModernPanelViewPresentation.h"

#import "PanelData.h"
#import "Encodings.h"


static void FormHumanReadableTimeRepresentation14(time_t _in, UniChar _out[14])
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    sprintf(buf, "%2.2d.%2.2d.%2.2d %2.2d:%2.2d",
            tt.tm_mday,
            tt.tm_mon + 1,
            tt.tm_year % 100,
            tt.tm_hour,
            tt.tm_min
            );
    
    for(int i = 0; i < 14; ++i) _out[i] = buf[i];
}

static void FormHumanReadableDateRepresentation8(time_t _in, UniChar _out[8])
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    sprintf(buf, "%2.2d.%2.2d.%2.2d",
            tt.tm_mday,
            tt.tm_mon + 1,
            tt.tm_year % 100
            );
    for(int i = 0; i < 8; ++i) _out[i] = buf[i];
}

static void FormHumanReadableTimeRepresentation5(time_t _in, UniChar _out[5])
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    sprintf(buf, "%2.2d:%2.2d", tt.tm_hour, tt.tm_min);
    
    for(int i = 0; i < 5; ++i) _out[i] = buf[i];
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

// Item name display insets inside the item line.
// Order: left, top, right, bottom.
const int g_TextInsetsInLine[4] = {7, 0, 5, 1};

const int g_DividerWidth = 2;

ModernPanelViewPresentation::ModernPanelViewPresentation()
:   m_DrawIcons(true)
{
    m_Size.width = m_Size.height = 0;
    
    m_Font = [NSFont fontWithName:@"Lucida Grande" size:13];
    m_HeaderFont = [NSFont fontWithName:@"Lucida Grande Bold" size:13];
    
    // Height of a single file line. Constant for now, needs to be calculated from the font.
    m_LineHeight = 18;
    m_HeaderHeight = m_LineHeight + 4;
}

void ModernPanelViewPresentation::Draw(NSRect _dirty_rect)
{
    if (!m_State || !m_State->Data) return;
    assert(m_State->CursorPos < (int)m_State->Data->SortedDirectoryEntries().size());
    assert(m_State->ItemsDisplayOffset >= 0);
    
    CGContextRef context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(context, 1, 1, 1, 1);
    CGContextFillRect(context, NSRectToCGRect(_dirty_rect));
    
    DrawShortView(context);
}

void ModernPanelViewPresentation::OnFrameChanged(NSRect _frame)
{
    m_Size = _frame.size;
    
    // TODO: Temporary hack!
    m_IsLeft = _frame.origin.x < 50;
    
    EnsureCursorIsVisible();
}

NSRect ModernPanelViewPresentation::GetItemColumnsRect()
{
    return NSMakeRect(0, m_HeaderHeight, m_Size.width, m_Size.height - 2*m_HeaderHeight);
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
    const int column_width = m_Size.width / columns;
    
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
    return int((m_Size.height - 2*m_HeaderHeight)/m_LineHeight);
}

void ModernPanelViewPresentation::DrawShortView(CGContextRef _context)
{
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    auto &entries = m_State->Data->DirectoryEntries();
    const int items_per_column = GetMaxItemsPerColumn();
    const int max_items = (int)sorted_entries.size();
    
    
    NSShadow *header_shadow = [[NSShadow alloc] init];
    header_shadow.shadowBlurRadius = 1;
    if (!m_State->Active)
        header_shadow.shadowColor = [NSColor colorWithDeviceRed:1 green:1 blue:1 alpha:0.9];
    else
        header_shadow.shadowColor = [NSColor colorWithDeviceRed:0.8 green:0.9 blue:1 alpha:1];
    header_shadow.shadowOffset = NSMakeSize(0, -1);
    
    NSMutableParagraphStyle *header_pstyle = [[NSMutableParagraphStyle alloc] init];
    header_pstyle.alignment = NSCenterTextAlignment;
    header_pstyle.lineBreakMode = NSLineBreakByTruncatingHead;
    NSMutableParagraphStyle *footer_pstyle = [[NSMutableParagraphStyle alloc] init];
    footer_pstyle.alignment = NSRightTextAlignment;
    footer_pstyle.lineBreakMode = NSLineBreakByTruncatingHead;
    NSMutableParagraphStyle *item_pstyle = [[NSMutableParagraphStyle alloc] init];
    item_pstyle.alignment = NSLeftTextAlignment;
    item_pstyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    NSDictionary *header_attr = @{NSFontAttributeName: m_Font, NSParagraphStyleAttributeName: header_pstyle, NSShadowAttributeName: header_shadow};
    NSDictionary *footer_attr = @{NSFontAttributeName: m_Font, NSParagraphStyleAttributeName:footer_pstyle, NSShadowAttributeName: header_shadow};
    NSDictionary *footer_attr2 = @{NSFontAttributeName: m_Font, NSParagraphStyleAttributeName: item_pstyle, NSShadowAttributeName: header_shadow};
    NSDictionary *attr = @{NSFontAttributeName: m_Font, NSParagraphStyleAttributeName: item_pstyle};
    NSDictionary *active_selected_attr = @{NSFontAttributeName: m_Font,
                                           NSForegroundColorAttributeName: [NSColor whiteColor],
                                           NSParagraphStyleAttributeName: item_pstyle};
    
    const CGFloat frame_comp = 102/255.0;
    
    CGGradientRef grad;
    if (!m_State->Active)
    {
        const CGFloat header_color_start = 220/255.0;
        const CGFloat header_color_mid = 220/255.0;
        const CGFloat header_color_mid2 = 200/255.0;
        const CGFloat header_color_end = 200/255.0;
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {
            header_color_start, header_color_start, header_color_start, 1.0,
            header_color_mid, header_color_mid, header_color_mid, 1.0,
            header_color_mid2, header_color_mid2, header_color_mid2, 1.0,
            header_color_end,header_color_end, header_color_end, 1.0};
        CGFloat locations[] = {0.0, 0.4, 0.7, 1.0};
        grad =
        CGGradientCreateWithColorComponents(color_space, components, locations, 4);
        CGColorSpaceRelease(color_space);
    }
    else
    {
        CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
        CGFloat components[] = {
            200/255.0, 230/255.0, 245/255.0, 1.0,
            130/255.0, 196/255.0, 240/255.0, 1.0,
            130/255.0, 196/255.0, 240/255.0, 1.0,
            200/255.0, 230/255.0, 245/255.0, 1.0 };
        CGFloat locations[] = {0.0, 0.4, 0.6, 1.0};
        grad =
        CGGradientCreateWithColorComponents(color_space, components, locations, 4);
        CGColorSpaceRelease(color_space);
    }
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Header.
    
    // Header gradient.
    CGContextSaveGState(_context);
    NSRect header_rect = NSMakeRect(0, 0, m_Size.width, m_HeaderHeight - 1);
    CGContextAddRect(_context, header_rect);
    CGContextClip(_context);
    CGContextDrawLinearGradient(_context, grad, header_rect.origin,
                                NSMakePoint(header_rect.origin.x, header_rect.origin.y + header_rect.size.height), 0);
    CGContextRestoreGState(_context);
    
    // Header line separator.
    CGContextSetRGBStrokeColor(_context, frame_comp, frame_comp, frame_comp, 1.0);
    NSPoint header_points[2] = {
        NSMakePoint(0, m_HeaderHeight - 0.5), NSMakePoint(m_Size.width, m_HeaderHeight - 0.5)
    };
    CGContextStrokeLineSegments(_context, header_points, 2);
    
    // Panel path.
    char panelpath[__DARWIN_MAXPATHLEN] = {0};
    m_State->Data->GetDirectoryPathWithTrailingSlash(panelpath);
    int delta = (m_HeaderHeight - m_LineHeight)/2;
    NSRect rect = NSMakeRect(20, delta, m_Size.width - 40, m_LineHeight);
    NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
    NSString *header_string = [NSString stringWithUTF8String:panelpath];
    [header_string drawWithRect:rect options:options attributes:header_attr];
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Footer.
    const int footer_y = m_Size.height - m_HeaderHeight;
    
    // Footer gradient.
    CGContextSaveGState(_context);
    NSRect footer_rect = NSMakeRect(0, footer_y + 1, m_Size.width, m_HeaderHeight - 1);
    CGContextAddRect(_context, footer_rect);
    CGContextClip(_context);
    CGContextDrawLinearGradient(_context, grad, footer_rect.origin,
                                NSMakePoint(footer_rect.origin.x, footer_rect.origin.y + footer_rect.size.height), 0);
    CGContextRestoreGState(_context);
    
    // Footer line separator.
    CGContextSetRGBStrokeColor(_context, frame_comp, frame_comp, frame_comp, 1.0);
    NSPoint footer_points[2] = {
        NSMakePoint(0, footer_y + 0.5), NSMakePoint(m_Size.width, footer_y + 0.5)
    };
    CGContextStrokeLineSegments(_context, footer_points, 2);
    
    // Footer string.
    if(m_State->CursorPos >= 0)
    {
        UniChar buff[256];
        UniChar time_info[14], size_info[6];
        size_t buf_size = 0;
        const DirectoryEntryInformation *current_entry = &entries[sorted_entries[m_State->CursorPos]];
        FormHumanReadableTimeRepresentation14(current_entry->mtime, time_info);
        FormHumanReadableSizeReprentationForDirEnt6(current_entry, size_info);
        ComposeFooterFileNameForEntry(*current_entry, buff, buf_size);
        
        NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
        int delta = (m_HeaderHeight - m_LineHeight)/2;
        int offset = 10;
        
        int time_width = 110;
        NSString *time_str = [NSString stringWithCharacters:time_info length:14];
        [time_str drawWithRect:NSMakeRect(m_Size.width - offset - time_width, footer_y + delta, time_width, m_LineHeight) options:options attributes:footer_attr];
        
        int size_width = 90;
        NSString *size_str = [NSString stringWithCharacters:size_info length:6];
        [size_str drawWithRect:NSMakeRect(m_Size.width - offset - time_width - size_width, footer_y + delta, size_width, m_LineHeight) options:options attributes:footer_attr];
        
        
        NSString *name_str = [NSString stringWithCharacters:buff length:buf_size];
        [name_str drawWithRect:NSMakeRect(offset, footer_y + delta, m_Size.width - 2*offset - time_width - size_width, m_LineHeight) options:options attributes:footer_attr2];
    }
    
    
    ///////////////////////////////////////////////////////////////////////////////
    // Divider.
    CGFloat comp[4] = {174/255.0, 174/255.0, 174/255.0, 1.0};
    CGContextSetFillColor(_context, comp);
    CGContextSetRGBStrokeColor(_context, frame_comp, frame_comp, frame_comp, 1.0);
    
    if (m_IsLeft)
    {
        float x = m_Size.width - 0.5 - g_DividerWidth;
        NSPoint view_divider[2] = {
            NSMakePoint(x, 0.5), NSMakePoint(x, m_Size.height + 0.5)
        };
        CGContextStrokeLineSegments(_context, view_divider, 2);
    
        CGContextSetFillColor(_context, comp);
        CGContextFillRect(_context, NSMakeRect(m_Size.width - g_DividerWidth, 0, g_DividerWidth, m_Size.height));
    }
    else
    {
        float x = 0.5 + g_DividerWidth;
        NSPoint view_divider[2] = {
            NSMakePoint(x, 0.5), NSMakePoint(x, m_Size.height + 0.5)
        };
        CGContextStrokeLineSegments(_context, view_divider, 2);
        
        CGContextSetFillColor(_context, comp);
        CGContextFillRect(_context, NSMakeRect(0, 0, g_DividerWidth, m_Size.height));
    }
        
    ///////////////////////////////////////////////////////////////////////////////
    // Draw items in columns.
    int start_y = m_HeaderHeight;
    int column_width = m_Size.width/3;
    for (int column = 0; column < 3; ++column)
    {
        // Draw column.
        // Calculate index of the first item in current column.
        int i = m_State->ItemsDisplayOffset + column*items_per_column;
        // X position of items.
        int start_x = column*column_width;
        
        if (column < 2)
        {
            NSPoint points[2] = {
                NSMakePoint(start_x - 0.5 + column_width, start_y),
                NSMakePoint(start_x - 0.5 + column_width, m_Size.height - m_HeaderHeight)
            };
            CGContextSetRGBStrokeColor(_context, 224/255.0, 224/255.0, 224/255.0, 1.0);
            CGContextSetLineWidth(_context, 1);
            CGContextStrokeLineSegments(_context, points, 2);
        }
        
        int count = 0;
        for (; count < items_per_column && i < max_items; ++count, ++i)
        {
            auto &item = entries[sorted_entries[i]];
            NSString *item_name = [NSString stringWithUTF8String:item.namec()];
            
            NSRect rect = NSMakeRect(start_x + g_TextInsetsInLine[0],
                                     start_y + count*m_LineHeight + g_TextInsetsInLine[1],
                                     column_width - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                     m_LineHeight - g_TextInsetsInLine[1] - g_TextInsetsInLine[3]);
            
            NSStringDrawingOptions options = NSStringDrawingUsesLineFragmentOrigin;
            
            if (m_DrawIcons)
            {
                
                rect.origin.x += 16 + g_TextInsetsInLine[0];
                rect.size.width -= 16 + g_TextInsetsInLine[0];
            }
            
            if (m_State->CursorPos == i && m_State->Active)
            {
                // Draw as cursor item (only if panel is active).
                // black on light blue or white on light blue, if the item is selected
                //CGContextSetRGBFillColor(_context, 43/255.0, 180/255.0, 255/255.0, 1.0);
                CGContextSetRGBFillColor(_context, 130/255.0, 196/255.0, 240/255.0, 1.0);
                CGContextFillRect(_context, NSMakeRect(start_x + 1, start_y + count*m_LineHeight + 1, column_width - 3, m_LineHeight - 1));
                
                if (item.cf_isselected())
                    [item_name drawWithRect:rect options:options attributes:active_selected_attr];
                else
                    [item_name drawWithRect:rect options:options attributes:attr];
            }
            else if (item.cf_isselected())
            {
                // Draw selected item.
                if (m_State->Active)
                {
                    // If panel is active, draw as white on dark blue.
                    CGContextSetRGBFillColor(_context, 43/255.0, 116/255.0, 211/255.0, 1.0);
                    CGContextFillRect(_context, NSMakeRect(start_x + 1, start_y + count*m_LineHeight + 1, column_width - 3, m_LineHeight - 1));
                    
                    [item_name drawWithRect:rect options:options attributes:active_selected_attr];
                }
                else
                {
                    // If panel is not active, draw as black on light grey.
                    CGFloat sel_comp = 212/255.0;
                    CGContextSetRGBFillColor(_context, sel_comp, sel_comp, sel_comp, 1.0);
                    CGContextFillRect(_context, NSMakeRect(start_x + 1, start_y + count*m_LineHeight + 1, column_width - 3, m_LineHeight - 1));
                
                    [item_name drawWithRect:rect options:options attributes:attr];
                }
            }
            else
            {
                // Draw ordinary item (black on white).
                [item_name drawWithRect:rect options:options attributes:attr];
            }
            
            if (m_DrawIcons)
            {
                char buf[1024];
                m_State->Data->GetDirectoryPathWithTrailingSlash(buf);
                if(!item.isdotdot())
                    strcat(buf, item.namec());
                NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:[NSString stringWithUTF8String:buf]];
                
                NSImageRep *image_rep = [image bestRepresentationForRect:NSMakeRect(0, 0, 16, 16) context:nil hints:nil];
                [image_rep drawInRect:NSMakeRect(start_x + g_TextInsetsInLine[0], start_y + count*m_LineHeight + m_LineHeight - 17, 16, 16) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
            }
        }
    }
    
    CGGradientRelease(grad);
}
