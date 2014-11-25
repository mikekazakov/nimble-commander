//
//  ModernPanelViewPresentation.cpp
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//


#import "PanelView.h"
#import "ModernPanelViewPresentation.h"
#import "PanelData.h"
#import "Encodings.h"
#import "Common.h"
#import "NSUserDefaults+myColorSupport.h"
#import "FontExtras.h"
#import "ObjcToCppObservingBridge.h"
#import "IconsGenerator.h"
#import "ModernPanelViewPresentationHeader.h"
#import "ModernPanelViewPresentationItemsFooter.h"
#import "ModernPanelViewPresentationVolumeFooter.h"
#import "ByteCountFormatter.h"

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

NSString* ModernPanelViewPresentation::FileSizeToString(const VFSListingItem &_dirent)
{
    if( _dirent.IsDir() )
    {
        if( _dirent.Size() != VFSListingItem::InvalidSize)
        {
            return ByteCountFormatter::Instance().ToNSString(_dirent.Size(), FileSizeFormat());
        }
        else
        {
            if(_dirent.IsDotDot())
                return @"Up";
            else
                return @"Folder";
        }
    }
    else
    {
        return ByteCountFormatter::Instance().ToNSString(_dirent.Size(), FileSizeFormat());
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// class ModernPanelViewPresentation
///////////////////////////////////////////////////////////////////////////////////////////////////
NSDictionary *ModernPanelViewPresentationItemsColoringFilter::Archive() const
{
    return @{@"name"    : [NSString stringWithUTF8String:name.c_str()],
             @"regular" : [NSArchiver archivedDataWithRootObject:regular],
             @"actsel"  : [NSArchiver archivedDataWithRootObject:actsel],
             @"filter"  : filter.Archive()
             };
};

ModernPanelViewPresentationItemsColoringFilter ModernPanelViewPresentationItemsColoringFilter::Unarchive(NSDictionary *_dict)
{
    ModernPanelViewPresentationItemsColoringFilter f;
    
    if(!_dict)
        return f;
    
    if([_dict objectForKey:@"filter"] &&
       [[_dict objectForKey:@"filter"] isKindOfClass:NSDictionary.class])
        f.filter = PanelViewPresentationItemsColoringFilter::Unarchive([_dict objectForKey:@"filter"]);
    
    if([_dict objectForKey:@"name"] &&
       [[_dict objectForKey:@"name"] isKindOfClass:NSString.class])
        f.name = [[_dict objectForKey:@"name"] UTF8String];
    
    if([_dict objectForKey:@"regular"] &&
       [[_dict objectForKey:@"regular"] isKindOfClass:NSData.class])
        f.regular = (NSColor *)[NSUnarchiver unarchiveObjectWithData:[_dict objectForKey:@"regular"]];
    
    if([_dict objectForKey:@"actsel"] &&
       [[_dict objectForKey:@"actsel"] isKindOfClass:NSData.class])
        f.actsel = (NSColor *)[NSUnarchiver unarchiveObjectWithData:[_dict objectForKey:@"actsel"]];
    
    return f;
}

// Item name display insets inside the item line.
// Order: left, top, right, bottom.
static const double g_TextInsetsInLine[4] = {7, 1, 5, 1};

NSImage *ModernPanelViewPresentation::m_SymlinkArrowImage = nil;

ModernPanelViewPresentation::ModernPanelViewPresentation():
    m_IconCache(make_shared<IconsGenerator>()),
    m_BackgroundColor(0),
    m_RegularOddBackgroundColor(0),
    m_ActiveSelectedItemBackgroundColor(0),
    m_InactiveSelectedItemBackgroundColor(0),
    m_CursorFrameColor(0),
    m_ColumnDividerColor(0),
    m_Header(make_unique<ModernPanelViewPresentationHeader>()),
    m_ItemsFooter(make_unique<ModernPanelViewPresentationItemsFooter>(this)),
    m_VolumeFooter(make_unique<ModernPanelViewPresentationVolumeFooter>())
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        m_SymlinkArrowImage = [NSImage imageNamed:@"linkarrow_icon.png"];
    });
    
    m_Size.width = m_Size.height = 0;

    m_IconCache->SetUpdateCallback([=]{
        dispatch_to_main_queue( ^{
            SetViewNeedsDisplay();
        });
    });
    BuildGeometry();
    BuildAppearance();
    
    m_GeometryObserver = [ObjcToCppObservingBlockBridge
                          bridgeWithObject:NSUserDefaults.standardUserDefaults
                          forKeyPaths:@[@"FilePanelsModernFont",
                                        @"FilePanelsGeneralShowVolumeInformationBar"]
                          options:0
                          block:^(NSString *_key_path, id _objc_object, NSDictionary *_changed) {
                              BuildGeometry();
                              CalculateLayoutFromFrame();
                              m_State->Data->CustomIconClearAll();
                              BuildAppearance();
                              SetViewNeedsDisplay();
                          }];
    
    m_AppearanceObserver = [ObjcToCppObservingBlockBridge
                            bridgeWithObject:NSUserDefaults.standardUserDefaults
                            forKeyPaths:@[@"FilePanelsModernBackgroundColor",
                                          @"FilePanelsModernAlternativeBackgroundColor",
                                          @"FilePanelsModernActiveSelectedBackgroundColor",
                                          @"FilePanelsModernInactiveSelectedBackgroundColor",
                                          @"FilePanelsModernCursorFrameColor",
                                          @"FilePanelsModernIconsMode",
                                          @"FilePanelsModernColoringRules"]
                            options:0
                            block:^(NSString *_key_path, id _objc_object, NSDictionary *_changed) {
                                BuildAppearance();
                                if([_key_path isEqualToString:@"FilePanelsModernIconsMode"])
                                    m_State->Data->CustomIconClearAll();
                                SetViewNeedsDisplay();
                            }];
}

ModernPanelViewPresentation::~ModernPanelViewPresentation()
{
    m_IconCache->SetUpdateCallback(nullptr);
    CGColorRelease(m_BackgroundColor);
    CGColorRelease(m_RegularOddBackgroundColor);
    CGColorRelease(m_ActiveSelectedItemBackgroundColor);
    CGColorRelease(m_InactiveSelectedItemBackgroundColor);
    CGColorRelease(m_CursorFrameColor);
    CGColorRelease(m_ColumnDividerColor);
    
    if(m_State->Data != 0)
        m_State->Data->CustomIconClearAll();
}

void ModernPanelViewPresentation::BuildGeometry()
{    
    // build font geometry according current settings
    m_Font = [NSUserDefaults.standardUserDefaults fontForKey:@"FilePanelsModernFont"];
    if(!m_Font) m_Font = [NSFont fontWithName:@"Lucida Grande" size:13];
    
    m_Header->SetFont(m_Font);
    m_ItemsFooter->SetFont(m_Font);
    
    // Height of a single file line calculated from the font.
    m_FontHeight = GetLineHeightForFont((__bridge CTFontRef)m_Font, &m_FontAscent);
    m_LineHeight = m_FontHeight + g_TextInsetsInLine[1] + g_TextInsetsInLine[3]; // + 1 + 1
    m_IconCache->SetIconSize(m_FontHeight);

    NSDictionary* attributes = [NSDictionary dictionaryWithObject:m_Font forKey:NSFontAttributeName];
    
    m_SizeColumWidth = ceil([@"999999" sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
    
    // 9 days after 1970
    m_DateColumnWidth = ceil([FormHumanReadableShortDate(777600) sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
    
    // to exclude possible issues with timezones, showing/not showing preffix zeroes and 12/24 stuff...
    // ... we do the following: take every in 24 hours and get the largest width
    m_TimeColumnWidth = 0;
    for(int i = 0; i < 24; ++i)
    {
        double tw = ceil([FormHumanReadableShortTime(777600 + i * 60 * 60) sizeWithAttributes:attributes].width)
            + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
        if(tw > m_TimeColumnWidth)
            m_TimeColumnWidth = tw;
    }
    
    bool need_volume_bar = [NSUserDefaults.standardUserDefaults boolForKey:@"FilePanelsGeneralShowVolumeInformationBar"];
    if(need_volume_bar && m_VolumeFooter == nullptr)
        m_VolumeFooter = make_unique<ModernPanelViewPresentationVolumeFooter>();
    else if(!need_volume_bar && m_VolumeFooter != nullptr)
        m_VolumeFooter.reset();
}

void ModernPanelViewPresentation::BuildAppearance()
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // Icon mode
    m_IconCache->SetIconMode((int)[defaults integerForKey:@"FilePanelsModernIconsMode"]);
    
    // Colors
    if(m_BackgroundColor) CGColorRelease(m_BackgroundColor);
    m_BackgroundColor = [defaults colorForKey:@"FilePanelsModernBackgroundColor"].copyCGColorRefSafe;

    if(m_RegularOddBackgroundColor) CGColorRelease(m_RegularOddBackgroundColor);
    m_RegularOddBackgroundColor = [defaults colorForKey:@"FilePanelsModernAlternativeBackgroundColor"].copyCGColorRefSafe;
    
    if(m_ActiveSelectedItemBackgroundColor) CGColorRelease(m_ActiveSelectedItemBackgroundColor);
    m_ActiveSelectedItemBackgroundColor = [defaults colorForKey:@"FilePanelsModernActiveSelectedBackgroundColor"].copyCGColorRefSafe;
    
    if(m_InactiveSelectedItemBackgroundColor) CGColorRelease(m_InactiveSelectedItemBackgroundColor);
    m_InactiveSelectedItemBackgroundColor = [defaults colorForKey:@"FilePanelsModernInactiveSelectedBackgroundColor"].copyCGColorRefSafe;
    
    if(m_CursorFrameColor) CGColorRelease(m_CursorFrameColor);
    m_CursorFrameColor = [defaults colorForKey:@"FilePanelsModernCursorFrameColor"].copyCGColorRefSafe;
    
    m_ColumnDividerColor = CGColorCreateGenericRGB(224/255.0, 224/255.0, 224/255.0, 1.0); // hard-coded for now
    
    // Coloring rules
    m_ColoringRules.clear();
    NSArray *coloring_rules = [NSUserDefaults.standardUserDefaults objectForKey:@"FilePanelsModernColoringRules"];
    if(coloring_rules && [coloring_rules isKindOfClass:NSArray.class])
        for(id item: coloring_rules)
            if([item isKindOfClass:NSDictionary.class])
                m_ColoringRules.emplace_back( ModernPanelViewPresentationItemsColoringFilter::Unarchive(item) );
    
    m_ColoringRules.emplace_back(); // always have a default ("others") non-filtering filter at the back
    
    // Coloring text attributes
    m_ColoringAttrs.clear();
    for(auto &c:m_ColoringRules) {
        m_ColoringAttrs.emplace_back();
        auto &ca = m_ColoringAttrs.back();
        
        NSMutableParagraphStyle *item_text_pstyle = [NSMutableParagraphStyle new];
        item_text_pstyle.alignment = NSLeftTextAlignment;
        item_text_pstyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    
        ca.active_selected = @{NSFontAttributeName: m_Font,
                               NSForegroundColorAttributeName: c.actsel,
                               NSParagraphStyleAttributeName: item_text_pstyle};
    
        ca.regular = @{NSFontAttributeName: m_Font,
                       NSForegroundColorAttributeName: c.regular,
                       NSParagraphStyleAttributeName: item_text_pstyle};
    
        NSMutableParagraphStyle *size_col_text_pstyle = [NSMutableParagraphStyle new];
        size_col_text_pstyle.alignment = NSRightTextAlignment;
        size_col_text_pstyle.lineBreakMode = NSLineBreakByClipping;

        ca.active_selected_size = @{NSFontAttributeName: m_Font,
                                    NSForegroundColorAttributeName: c.actsel,
                                    NSParagraphStyleAttributeName: size_col_text_pstyle};

        ca.regular_size = @{NSFontAttributeName: m_Font,
                            NSForegroundColorAttributeName: c.regular,
                            NSParagraphStyleAttributeName: size_col_text_pstyle};

        ca.active_selected_time = @{NSFontAttributeName: m_Font,
                                    NSForegroundColorAttributeName: c.actsel,
                                    NSParagraphStyleAttributeName: size_col_text_pstyle};
    
        ca.regular_time = @{NSFontAttributeName: m_Font,
                            NSForegroundColorAttributeName: c.regular,
                            NSParagraphStyleAttributeName: size_col_text_pstyle};
    }
}

void ModernPanelViewPresentation::Draw(NSRect _dirty_rect)
{
    if (!m_State || !m_State->Data) return;
    assert(m_State->CursorPos < (int)m_State->Data->SortedDirectoryEntries().size());
    assert(m_State->ItemsDisplayOffset >= 0);
    
    auto &entries = m_State->Data->DirectoryEntries();
    const int items_per_column = GetMaxItemsPerColumn();
    const int columns_count = GetNumberOfItemColumns();
    const bool active = View().active;
    const bool wnd_active = NSView.focusView.window.isKeyWindow;
    
    ///////////////////////////////////////////////////////////////////////////////
    // Clear view background.
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    CGContextSetFillColorWithColor(context, m_BackgroundColor);
    // don't paint areas of header and footer
    CGRect bk_fill_rect = NSRectToCGRect(_dirty_rect);
    bk_fill_rect.origin.y += m_Header->Height();
    bk_fill_rect.size.height -= m_Header->Height() + m_ItemsFooter->Height();
    CGContextFillRect(context, bk_fill_rect);

    // If current panel is on the right, then translate all rendering by the divider's width.
    CGContextSaveGState(context);
    
    // Header
    string panelpath = m_State->Data->VerboseDirectoryFullPath();
    m_Header->Draw(panelpath, active, wnd_active, m_ItemsArea.size.width, m_State->Data->SortMode().sort);
    
    // Footer
    m_ItemsFooter->Draw(View().item,
                        m_State->Data->Stats(),
                        m_State->ViewType,
                        active,
                        wnd_active,
                        m_ItemsArea.origin.y + m_ItemsArea.size.height,
                        m_ItemsArea.size.width);
    
    // Volume footer if any
    if(m_VolumeFooter)
    {
        UpdateStatFS();
        m_VolumeFooter->Draw(StatFS(),
                             wnd_active,
                             m_ItemsArea.origin.y + m_ItemsArea.size.height + m_ItemsFooter->Height(),
                             m_ItemsArea.size.width
                             );
    }
    
    ///////////////////////////////////////////////////////////////////////////////
    // Draw items in columns.        
    const double icon_size = m_IconCache->IconSize();
    const double start_y = m_ItemsArea.origin.y;
    double full_view_max_date_width = 0;
    double full_wide_view_max_time_width = 0;
        
    for (int column = 0; column < columns_count; ++column)
    {
        // Draw column.
        double column_width = floor((m_ItemsArea.size.width - (columns_count - 1))/columns_count);
        // Calculate index of the first item in current column.
        int i = m_State->ItemsDisplayOffset + column*items_per_column;
        // X position of items.
        double start_x = column*(column_width + 1);
        
        if (column == columns_count - 1)
            column_width += int(m_ItemsArea.size.width - (columns_count - 1))%columns_count;
        
        // Draw column divider.
        if (column < columns_count - 1)
        {
            NSPoint points[2] = {
                NSMakePoint(start_x + 0.5 + column_width, start_y),
                NSMakePoint(start_x + 0.5 + column_width, start_y + m_ItemsArea.size.height)
            };
            CGContextSetStrokeColorWithColor(context, m_ColumnDividerColor);
            CGContextSetLineWidth(context, 1);
            CGContextStrokeLineSegments(context, points, 2);
        }
        
        int count = 0;
        for (; count < items_per_column; ++count, ++i)
        {
            const double item_start_y = start_y + count*m_LineHeight;
            const VFSListingItem *item = m_State->Data->EntryAtSortPosition(i);
            
            // Draw background.
            if (item && item->CFIsSelected())
            {
                // Draw selected item.
                if (active && wnd_active)
                {
                    int offset = (m_State->CursorPos == i) ? 2 : 1;
                    CGContextSetFillColorWithColor(context, m_ActiveSelectedItemBackgroundColor);
                    CGContextFillRect(context, NSMakeRect(start_x + offset,
                                                          item_start_y + offset,
                                                          column_width - 2*offset,
                                                          m_LineHeight - 2*offset + 1));
                }
                else
                {
                    CGContextSetFillColorWithColor(context, m_InactiveSelectedItemBackgroundColor);
                    CGContextFillRect(context, NSMakeRect(start_x + 1,
                                                          item_start_y + 1,
                                                          column_width - 2, m_LineHeight - 1));
                }
            }
            else if (count % 2 == 1)
            {
                CGContextSetFillColorWithColor(context, m_RegularOddBackgroundColor);
                CGContextFillRect(context, NSMakeRect(start_x + 1, item_start_y + 1,
                                                      column_width - 2, m_LineHeight - 1));
            }
            
            if (!item) continue;
            
            // Draw as cursor item (only if panel is active).
            if (m_State->CursorPos == i && active && wnd_active)
                DrawCursor(context, NSMakeRect(start_x + 1.5,
                                               item_start_y + 1.5,
                                               column_width - 3, m_LineHeight - 2));
            
            const ColoringAttrs& attrs = AttrsForItem(*item);
            const bool actsel = active && item->CFIsSelected();
            
            NSRect rect = NSMakeRect(start_x + icon_size + 2*g_TextInsetsInLine[0],
                       item_start_y + g_TextInsetsInLine[1] + m_FontAscent,
                       column_width - icon_size - 2*g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                       m_FontHeight);
            
            // Draw stats columns for specific views.
            int spec_col_x = m_ItemsArea.size.width;
            if (m_State->ViewType == PanelViewType::ViewFull) {
                NSRect time_rect = NSMakeRect(spec_col_x - m_TimeColumnWidth + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              m_TimeColumnWidth - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);
                NSString *time_str = FormHumanReadableShortTime(item->MTime());
                NSDictionary *attr = actsel ? attrs.active_selected_time : attrs.regular_time;
                NSRect time_str_real_rc = [time_str boundingRectWithSize:NSMakeSize(10000, 100)
                                                                 options:0
                                                              attributes:attr];
                if( time_str_real_rc.size.width > full_wide_view_max_time_width)
                    full_wide_view_max_time_width = time_str_real_rc.size.width;
                [time_str drawWithRect:time_rect
                               options:0
                            attributes:attr];
                
                
                rect.size.width -= m_TimeColumnWidth;
                spec_col_x -= m_TimeColumnWidth;
                
                
                NSRect date_rect = NSMakeRect(spec_col_x - m_DateColumnWidth + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              m_DateColumnWidth - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);
                NSString *date_str = FormHumanReadableShortDate(item->MTime());
                NSRect date_str_real_rc = [date_str boundingRectWithSize:NSMakeSize(10000, 100)
                                                                 options:0
                                                              attributes:attr];
                if(date_str_real_rc.size.width > full_view_max_date_width)
                    full_view_max_date_width = date_str_real_rc.size.width;
                [date_str drawWithRect:date_rect
                               options:0
                            attributes:attr];

                rect.size.width -= m_DateColumnWidth;
                spec_col_x -= m_DateColumnWidth;
            }
            if(m_State->ViewType == PanelViewType::ViewWide || m_State->ViewType == PanelViewType::ViewFull) {
                // draw the entry size on the right
                NSRect size_rect = NSMakeRect(spec_col_x - m_SizeColumWidth + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              m_SizeColumWidth - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);

                [FileSizeToString(*item) drawWithRect:size_rect
                                              options:0
                                           attributes:actsel ? attrs.active_selected_size : attrs.regular_size];
                
                rect.size.width -= m_SizeColumWidth;
            }

            // Draw item text.
            NSDictionary *item_text_attr = actsel ? attrs.active_selected : attrs.regular;
            if(rect.size.width > 0)
                [item->NSDisplayName() drawWithRect:rect options:0 attributes:item_text_attr];
            
            // Draw icon
            NSImageRep *image_rep = m_IconCache->ImageFor(m_State->Data->RawIndexForSortIndex(i), (VFSListing&)entries); // UGLY anti-const hack
            [image_rep drawInRect:NSMakeRect(start_x + g_TextInsetsInLine[0],
                                             item_start_y + floor((m_LineHeight - icon_size) / 2. + 0.5),
                                             icon_size,
                                             icon_size)
                         fromRect:NSZeroRect
                        operation:NSCompositeSourceOver
                         fraction:1.0
                   respectFlipped:YES
                            hints:nil];
            
            // Draw symlink arrow over an icon
            if(item->IsSymlink())
                [m_SymlinkArrowImage drawInRect:NSMakeRect(start_x + g_TextInsetsInLine[0],
                                                           item_start_y + m_LineHeight - m_SymlinkArrowImage.size.height - 1,
                                                           m_SymlinkArrowImage.size.width,
                                                           m_SymlinkArrowImage.size.height)
                                       fromRect:NSZeroRect
                                      operation:NSCompositeSourceOver
                                       fraction:1.0
                                 respectFlipped:YES
                                          hints:nil];
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
        CGContextSetStrokeColorWithColor(context, m_ColumnDividerColor);
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
            CGContextSetStrokeColorWithColor(context, m_ColumnDividerColor);
            CGContextSetLineWidth(context, 1);
            CGContextStrokeLineSegments(context, points, 2);
        }
    }
    
    // correct our predicted layout by really rendered geometry
    if(full_view_max_date_width + g_TextInsetsInLine[0] + g_TextInsetsInLine[2] > m_DateColumnWidth)
        m_DateColumnWidth = floor(full_view_max_date_width + g_TextInsetsInLine[0] + g_TextInsetsInLine[2]);
    
    if(full_wide_view_max_time_width + g_TextInsetsInLine[0] + g_TextInsetsInLine[2] > m_TimeColumnWidth)
        m_TimeColumnWidth = floor(full_wide_view_max_time_width + g_TextInsetsInLine[0] + g_TextInsetsInLine[2]);
    
    CGContextRestoreGState(context);    
}

void ModernPanelViewPresentation::OnFrameChanged(NSRect _frame)
{
    m_Size = _frame.size;
    m_IsLeft = _frame.origin.x < 50;
    CalculateLayoutFromFrame();
}

const ModernPanelViewPresentation::ColoringAttrs& ModernPanelViewPresentation::AttrsForItem(const VFSListingItem& _item) const
{
    size_t i = 0, e = m_ColoringRules.size();
    for(;i<e;++i)
        if(m_ColoringRules[i].filter.Filter(_item)) {
            assert(i < m_ColoringAttrs.size());
            return m_ColoringAttrs[i];
        }
    
    static ColoringAttrs dummy;
    return dummy;
}

void ModernPanelViewPresentation::CalculateLayoutFromFrame()
{
    // Header and footer have the same height.
    const int header_height = m_LineHeight + 1;
    
    m_ItemsArea.origin.x = 0;
    m_ItemsArea.origin.y = header_height;
    m_ItemsArea.size.height = floor(m_Size.height - 2*header_height);
    if(m_VolumeFooter)
        m_ItemsArea.size.height -= m_VolumeFooter->Height();
    
    m_ItemsArea.size.width = floor(m_Size.width);
    
    m_ItemsPerColumn = int(m_ItemsArea.size.height/m_LineHeight);
    
    EnsureCursorIsVisible();
}

NSRect ModernPanelViewPresentation::GetItemColumnsRect()
{
    return m_ItemsArea;
}

int ModernPanelViewPresentation::GetItemIndexByPointInView(CGPoint _point, PanelViewHitTest::Options _opt)
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
    if (file_number >= visible_files)
        return -1;
    
    int index = m_State->ItemsDisplayOffset + file_number;
    
    // now check that index against requested hit-test
    if( _opt != PanelViewHitTest::FullArea ) {
        auto origin = ItemOrigin(index);
        auto il = LayoutItem(index);
        
        if( _opt == PanelViewHitTest::FilenameArea )
            if( !NSPointInRect(_point, NSOffsetRect(il.filename_area, origin.x, origin.y)) )
                return -1;
        
        if( _opt == PanelViewHitTest::FilenameFact )
            if( !NSPointInRect(_point, NSOffsetRect(il.filename_fact, origin.x, origin.y)) )
                return -1;
    }
    
    return index;
}

NSPoint ModernPanelViewPresentation::ItemOrigin(int _item_index) const
{
    if(!IsItemVisible(_item_index))
        return {0,0};
    
    int columns = GetNumberOfItemColumns();
    int entries_in_column = GetMaxItemsPerColumn();
    int scrolled_index = _item_index - m_State->ItemsDisplayOffset;
    int column = scrolled_index / entries_in_column;
    int row = scrolled_index % entries_in_column;
    double column_width = floor((m_ItemsArea.size.width - (columns - 1))/columns);
    return NSMakePoint( column*(column_width + 1),
                        m_ItemsArea.origin.y + row*m_LineHeight
                       );
}

// NB!
// if someday this function become a bottleneck - add flags to specify what to calculate
ModernPanelViewPresentation::ItemLayout ModernPanelViewPresentation::LayoutItem(int _item_index) const
{
    ItemLayout il;
    
    const int columns = GetNumberOfItemColumns();
    const int entries_in_column = GetMaxItemsPerColumn();
    const int max_files_to_show = entries_in_column * columns;
    if(_item_index < m_State->ItemsDisplayOffset)
        return il;
    const int scrolled_index = _item_index - m_State->ItemsDisplayOffset;
    if(scrolled_index >= max_files_to_show)
        return il;

    const double column_width = floor((m_ItemsArea.size.width - (columns - 1))/columns);
    const double row_height   = m_LineHeight;
    const double icon_size    = m_IconCache->IconSize();
    
    il.whole_area.size.width    = column_width;
    il.whole_area.size.height   = row_height;
    
    il.icon = NSMakeRect(g_TextInsetsInLine[0], floor((m_LineHeight - icon_size) / 2. + 0.5),
                         icon_size, icon_size);
    
    NSRect filename_rect = NSMakeRect(icon_size + 2*g_TextInsetsInLine[0], 0,
                             column_width - icon_size - 2*g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                             m_FontHeight);
    if (m_State->ViewType == PanelViewType::ViewFull)
        filename_rect.size.width -= m_TimeColumnWidth + m_DateColumnWidth;
    if(m_State->ViewType == PanelViewType::ViewWide || m_State->ViewType == PanelViewType::ViewFull)
        filename_rect.size.width -= m_SizeColumWidth;
    if(filename_rect.size.width < 0)
        filename_rect.size.width = 0;
    
    il.filename_area = filename_rect;
    
    const VFSListingItem *item = m_State->Data->EntryAtSortPosition(_item_index);
    if(!item)
        return il;
    
    if(filename_rect.size.width > 0) {
        NSRect rc = [item->NSDisplayName() boundingRectWithSize:filename_rect.size
                                                        options:0
                                                     attributes:AttrsForItem(*item).regular];
        
        il.filename_fact = il.filename_area;
        il.filename_fact.size.width = rc.size.width;
    }
    return il;
}

NSRect ModernPanelViewPresentation::ItemRect(int _item_index) const
{
    if(!IsItemVisible(_item_index))
        return NSMakeRect(0, 0, -1, -1);
    
    NSPoint origin = ItemOrigin(_item_index);
    return NSOffsetRect(LayoutItem(_item_index).whole_area, origin.x, origin.y);
}

NSRect ModernPanelViewPresentation::ItemFilenameRect(int _item_index) const
{
    if(!IsItemVisible(_item_index))
        return NSMakeRect(0, 0, -1, -1);
    
    NSPoint origin = ItemOrigin(_item_index);
    return NSOffsetRect(LayoutItem(_item_index).filename_area, origin.x, origin.y);
}

int ModernPanelViewPresentation::GetMaxItemsPerColumn() const
{
    return m_ItemsPerColumn;
}

void ModernPanelViewPresentation::OnDirectoryChanged()
{
    m_IconCache->Flush();
}

double ModernPanelViewPresentation::GetSingleItemHeight()
{
    return m_LineHeight;
}

void ModernPanelViewPresentation::DrawCursor(CGContextRef _context, NSRect _rc)
{
    CGContextSaveGState(_context);
    CGFloat dashes[2] = { 2, 4 };
    CGContextSetLineDash(_context, 0, dashes, 2);
    CGContextSetStrokeColorWithColor(_context, m_CursorFrameColor);
    CGContextStrokeRect(_context, _rc);
    CGContextRestoreGState(_context);
}

void ModernPanelViewPresentation::SetupFieldRenaming(NSScrollView *_editor, int _item_index)
{
    NSPoint origin = ItemOrigin(_item_index);
    NSRect rc = NSOffsetRect(LayoutItem(_item_index).filename_area, origin.x, origin.y);
    auto line_padding = 2.;
    rc.origin.x -= line_padding;
    rc.origin.y += g_TextInsetsInLine[1];
    rc.size.width += line_padding;
    
    _editor.frame = rc;

    NSTextView *tv = _editor.documentView;
    tv.font = m_Font;
    tv.maxSize = NSMakeSize(FLT_MAX, rc.size.height);
    tv.textContainerInset = NSMakeSize(0, 0);
    tv.textContainer.lineFragmentPadding = line_padding;
}

void ModernPanelViewPresentation::SetQuickSearchPrompt(NSString *_text)
{
    m_Header->SetQuickSearchPrompt(_text);
}
