//
//  ModernPanelViewPresentation.cpp
//  Files
//
//  Created by Pavel Dogurevich on 11.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "Utility/HexadecimalColor.h"
#include "Utility/Encodings.h"
#include "PanelView.h"
#include "ModernPanelViewPresentation.h"
#include "PanelData.h"
#include "IconsGenerator.h"
#include "ModernPanelViewPresentationHeader.h"
#include "ModernPanelViewPresentationItemsFooter.h"
#include "ModernPanelViewPresentationVolumeFooter.h"
#include "ByteCountFormatter.h"

static const auto g_ConfigShowVolumeBar         = "filePanel.general.showVolumeInformationBar";
static const auto g_ConfigFontSize              = "filePanel.modern.fontSize";
static const auto g_ConfigIconsMode             = "filePanel.modern.iconsMode";
static const auto g_ConfigRegularBackground     = "filePanel.modern.regularBackground";
static const auto g_ConfigAlternativeBackground = "filePanel.modern.alternativeBackground";
static const auto g_ConfigColulmnDivider        = "filePanel.modern.columnDivider";
static const auto g_ConfigActiveCursor          = "filePanel.modern.activeCursor";
static const auto g_ConfigInactiveCursor        = "filePanel.modern.inactiveCursor";
static const auto g_ConfigColoring              = "filePanel.modern.coloringRules_v1";

static NSString* FormHumanReadableShortDate(time_t _in)
{
    static NSDateFormatter *date_formatter = nil;
    static once_flag once;
    call_once(once, []{
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
    static once_flag once;
    call_once(once, []{
        date_formatter = [NSDateFormatter new];
        [date_formatter setLocale:[NSLocale currentLocale]];
        [date_formatter setDateStyle:NSDateFormatterNoStyle];       // no date
        [date_formatter setTimeStyle:NSDateFormatterShortStyle];    // short time
    });
    
    return [date_formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:_in]];
}

NSString* ModernPanelViewPresentation::FileSizeToString(const VFSListingItem &_dirent, const PanelData::PanelVolatileData &_vd) const
{
    if( _dirent.IsDir() ) {
        if( _vd.is_size_calculated() ) {
            return ByteCountFormatter::Instance().ToNSString(_vd.size, FileSizeFormat());
        }
        else {
            if(_dirent.IsDotDot())
                return NSLocalizedString(@"__MODERNPRESENTATION_UP_WORD", "Upper-level in directory, for English is 'Up'");
            else
                return NSLocalizedString(@"__MODERNPRESENTATION_FOLDER_WORD", "Folders dummy string when size is not available, for English is 'Folder'");
        }
    }
    else {
        return ByteCountFormatter::Instance().ToNSString(_dirent.Size(), FileSizeFormat());
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////
// class ModernPanelViewPresentation
///////////////////////////////////////////////////////////////////////////////////////////////////
static NSColor *ColorFromConfig(const char *_path)
{
    return [NSColor colorWithHexStdString:GlobalConfig().GetString(_path).value_or("")];
}

// Item name display insets inside the item line.
// Order: left, top, right, bottom.
static const double g_TextInsetsInLine[4] = {7, 1, 5, 1};

NSImage *ModernPanelViewPresentation::m_SymlinkArrowImage = nil;

ModernPanelViewPresentation::ModernPanelViewPresentation(PanelView *_parent_view, PanelViewState *_view_state):
    PanelViewPresentation(_parent_view, _view_state),
    m_RegularBackground(0),
    m_OddBackground(0),
    m_ActiveCursor(0),
    m_InactiveCursor(0),
    m_ColumnDividerColor(0),
    m_Header(make_unique<ModernPanelViewPresentationHeader>()),
    m_ItemsFooter(make_unique<ModernPanelViewPresentationItemsFooter>(this)),
    m_VolumeFooter(make_unique<ModernPanelViewPresentationVolumeFooter>())
{
    static once_flag once;
    call_once(once, []{
        m_SymlinkArrowImage = [NSImage imageNamed:@"linkarrow_icon"];
    });
    
    m_Size.width = m_Size.height = 0;

    m_IconCache.SetUpdateCallback([=]{
        SetViewNeedsDisplay();
    });
    BuildGeometry();
    BuildAppearance();
    
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigShowVolumeBar,[=]{ OnGeometryOptionsChanged(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigFontSize,     [=]{ OnGeometryOptionsChanged(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigIconsMode,             [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigRegularBackground,     [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigAlternativeBackground, [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigColulmnDivider,        [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigActiveCursor,          [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigInactiveCursor,        [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigColoring,              [=]{ BuildAppearance(); }));
}

ModernPanelViewPresentation::~ModernPanelViewPresentation()
{
    m_IconCache.SetUpdateCallback(nullptr);
    
    if(m_State->Data != 0)
        m_State->Data->CustomIconClearAll();
}

void ModernPanelViewPresentation::OnGeometryOptionsChanged()
{
    m_State->Data->__InvariantCheck();
    BuildGeometry();
    CalculateLayoutFromFrame();
    m_State->Data->CustomIconClearAll();
    BuildAppearance();
    SetViewNeedsDisplay();
}

void ModernPanelViewPresentation::BuildGeometry()
{
    // build font geometry according current settings
    m_Font = [NSFont systemFontOfSize:GlobalConfig().GetInt(g_ConfigFontSize)];
    if(!m_Font) m_Font = [NSFont systemFontOfSize:13];
    if(!m_Font) m_Font = [NSFont fontWithName:@"Lucida Grande" size:13];
    
    // Height of a single file line calculated from the font.
    m_FontInfo = FontGeometryInfo( (__bridge CTFontRef)m_Font );
    
    // hardcoded stuff to mimic Finder's layout
    int icon_size = 16;
    switch ( (int)floor(m_Font.pointSize+0.5) ) {
        case 10:
        case 11:
            m_LineHeight = 17;
            m_LineTextBaseline = m_LineHeight - 5;
            break;
        case 12:
            m_LineHeight = 19;
            m_LineTextBaseline = m_LineHeight - 5;
            break;
        case 13:
        case 14:
            m_LineHeight = 19;
            m_LineTextBaseline = m_LineHeight - 4;
            break;
        case 15:
            m_LineHeight = 21;
            m_LineTextBaseline = m_LineHeight - 6;
            break;
        case 16:
            m_LineHeight = 22;
            m_LineTextBaseline = m_LineHeight - 6;
            break;
        default:
            m_LineHeight = m_FontInfo.LineHeight() + g_TextInsetsInLine[1] + g_TextInsetsInLine[3];
            m_LineTextBaseline = g_TextInsetsInLine[1] + m_FontInfo.Ascent();
            icon_size = m_FontInfo.LineHeight();
    }
    
    m_IconCache.SetIconSize( icon_size );

    NSDictionary* attributes = [NSDictionary dictionaryWithObject:m_Font forKey:NSFontAttributeName];
    
    m_SizeColumWidth = ceil([@"999999" sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
    
    // 9 days after 1970
    m_DateColumnWidth = ceil([FormHumanReadableShortDate(777600) sizeWithAttributes:attributes].width) + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
    
    // to exclude possible issues with timezones, showing/not showing preffix zeroes and 12/24 stuff...
    // ... we do the following: take every in 24 hours and get the largest width
    m_TimeColumnWidth = 0;
    for(int i = 0; i < 24; ++i) {
        double tw = ceil([FormHumanReadableShortTime(777600 + i * 60 * 60) sizeWithAttributes:attributes].width)
            + g_TextInsetsInLine[0] + g_TextInsetsInLine[2];
        if(tw > m_TimeColumnWidth)
            m_TimeColumnWidth = tw;
    }
    
    bool need_volume_bar = GlobalConfig().GetBool( g_ConfigShowVolumeBar );
    if(need_volume_bar && m_VolumeFooter == nullptr)
        m_VolumeFooter = make_unique<ModernPanelViewPresentationVolumeFooter>();
    else if(!need_volume_bar && m_VolumeFooter != nullptr)
        m_VolumeFooter.reset();
}

static NSLineBreakMode PanelViewFilenameTrimmingToLineBreakMode(PanelViewFilenameTrimming _method)
{
    if( _method == PanelViewFilenameTrimming::Heading )
        return NSLineBreakByTruncatingHead;
    if( _method == PanelViewFilenameTrimming::Trailing )
        return NSLineBreakByTruncatingTail;
    return NSLineBreakByTruncatingMiddle;
}

void ModernPanelViewPresentation::BuildAppearance()
{
    assert(dispatch_is_main_queue()); // STA api design
    
    // Icon mode
    if( (IconsGenerator::IconMode)GlobalConfig().GetInt(g_ConfigIconsMode) != m_IconCache.GetIconMode() ) {
        m_IconCache.SetIconMode( (IconsGenerator::IconMode)GlobalConfig().GetInt(g_ConfigIconsMode) );
        m_State->Data->CustomIconClearAll();
    }
    
    // Colors
    m_RegularBackground = ColorFromConfig(g_ConfigRegularBackground);
    m_OddBackground     = ColorFromConfig(g_ConfigAlternativeBackground);
    m_ActiveCursor      = ColorFromConfig(g_ConfigActiveCursor);
    m_InactiveCursor    = ColorFromConfig(g_ConfigInactiveCursor);
    m_ColumnDividerColor= ColorFromConfig(g_ConfigColulmnDivider);
    
    // Coloring rules
    m_ColoringRules.clear();
    {
        auto cr = GlobalConfig().Get(g_ConfigColoring);
        if( cr.IsArray() )
            for( auto i = cr.Begin(), e = cr.End(); i != e; ++i )
                m_ColoringRules.emplace_back( PanelViewPresentationItemsColoringRule::FromJSON(*i) );
    }
    
    m_ColoringRules.emplace_back(); // always have a default ("others") non-filtering filter at the back
    
    // Coloring text attributes
    m_ColoringAttrs.clear();
    for(auto &c:m_ColoringRules) {
        m_ColoringAttrs.emplace_back();
        auto &ca = m_ColoringAttrs.back();
        
        if(NSMutableParagraphStyle *item_text_pstyle = [NSMutableParagraphStyle new]) {
            item_text_pstyle.alignment = NSLeftTextAlignment;
            item_text_pstyle.lineBreakMode = PanelViewFilenameTrimmingToLineBreakMode(Trimming());
            
            ca.focused = @{NSFontAttributeName: m_Font,
                           NSForegroundColorAttributeName: c.focused,
                           NSParagraphStyleAttributeName: item_text_pstyle};
            
            ca.regular = @{NSFontAttributeName: m_Font,
                           NSForegroundColorAttributeName: c.regular,
                           NSParagraphStyleAttributeName: item_text_pstyle};
        }
    
        if( NSMutableParagraphStyle *size_col_text_pstyle = [NSMutableParagraphStyle new] ) {
            size_col_text_pstyle.alignment = NSRightTextAlignment;
            size_col_text_pstyle.lineBreakMode = NSLineBreakByClipping;
            
            ca.focused_size = @{NSFontAttributeName: m_Font,
                                NSForegroundColorAttributeName: c.focused,
                                NSParagraphStyleAttributeName: size_col_text_pstyle};
            
            ca.regular_size = @{NSFontAttributeName: m_Font,
                                NSForegroundColorAttributeName: c.regular,
                                NSParagraphStyleAttributeName: size_col_text_pstyle};
            
            ca.focused_time = @{NSFontAttributeName: m_Font,
                                NSForegroundColorAttributeName: c.focused,
                                NSParagraphStyleAttributeName: size_col_text_pstyle};
            
            ca.regular_time = @{NSFontAttributeName: m_Font,
                                NSForegroundColorAttributeName: c.regular,
                                NSParagraphStyleAttributeName: size_col_text_pstyle};
        }
    }
    SetViewNeedsDisplay();
}

void ModernPanelViewPresentation::OnPanelTitleChanged()
{
    m_Header->SetTitle(View().headerTitle);
}

void ModernPanelViewPresentation::Draw(NSRect _dirty_rect)
{
    if (!m_State || !m_State->Data) return;
    assert(m_State->CursorPos < (int)m_State->Data->SortedDirectoryEntries().size());
    assert(m_State->ItemsDisplayOffset >= 0);
    
    const int items_per_column = GetMaxItemsPerColumn();
    const int columns_count = GetNumberOfItemColumns();
    const bool active = View().active;
    const bool wnd_active = NSView.focusView.window.isKeyWindow;
    const bool is_listing_uniform = m_State->Data->Listing().IsUniform();
    
    ///////////////////////////////////////////////////////////////////////////////
    // Clear view background.
    CGContextRef context = (CGContextRef)NSGraphicsContext.currentContext.graphicsPort;
    CGContextSetFillColorWithColor(context, m_RegularBackground.CGColor);
    // don't paint areas of header and footer
    CGRect bk_fill_rect = NSRectToCGRect(_dirty_rect);
    bk_fill_rect.origin.y += m_Header->Height();
    bk_fill_rect.size.height -= m_Header->Height() + m_ItemsFooter->Height();
    CGContextFillRect(context, bk_fill_rect);

    // If current panel is on the right, then translate all rendering by the divider's width.
    CGContextSaveGState(context);
    
    // Header
    m_Header->Draw(active, wnd_active, m_ItemsArea.size.width, m_State->Data->SortMode().sort);
    
    // Footer
    m_ItemsFooter->Draw(View().item,
                        View().item_vd,
                        m_State->Data->Stats(),
                        m_State->ViewType,
                        active,
                        wnd_active,
                        m_ItemsArea.origin.y + m_ItemsArea.size.height,
                        m_ItemsArea.size.width);
    
    // Volume footer if any
    if(m_VolumeFooter) {
        UpdateStatFS();
        m_VolumeFooter->Draw(StatFS(),
                             wnd_active,
                             m_ItemsArea.origin.y + m_ItemsArea.size.height + m_ItemsFooter->Height(),
                             m_ItemsArea.size.width
                             );
    }
    
    ///////////////////////////////////////////////////////////////////////////////
    // Draw items in columns.        
    const double icon_size = m_IconCache.IconSize();
    const double start_y = m_ItemsArea.origin.y + 1;
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
                NSMakePoint(start_x + 0.5 + column_width, m_ItemsArea.origin.y),
                NSMakePoint(start_x + 0.5 + column_width, m_ItemsArea.origin.y + m_ItemsArea.size.height)
            };
            CGContextSetStrokeColorWithColor(context, m_ColumnDividerColor.CGColor);
            CGContextSetLineWidth(context, 1);
            CGContextStrokeLineSegments(context, points, 2);
        }
        
        for( int count = 0; count < items_per_column+1; ++count, ++i ) { // explicit +1 to draw odd backgrounds
            const double item_start_y = start_y + count*m_LineHeight;
            
            // Draw alternate background.
            if( count % 2 == 1 ) {
                const auto odd_bg_rct = NSMakeRect(start_x + 1, item_start_y, column_width - 2, m_LineHeight);
                CGContextSetFillColorWithColor(context, m_OddBackground.CGColor);
                CGContextFillRect(context, NSIntersectionRect(odd_bg_rct, m_ItemsArea));
            }
            
            const int raw_index = m_State->Data->RawIndexForSortIndex(i);
            const auto item = m_State->Data->EntryAtRawPosition(raw_index);
            
            if( !item )
                continue;
            
            auto &item_vd = m_State->Data->VolatileDataAtRawPosition(raw_index);

            if(m_State->CursorPos == i) {
                if (active && wnd_active) {
                    CGContextSetFillColorWithColor(context, m_ActiveCursor.CGColor);
                    CGContextFillRect(context, NSMakeRect(start_x + 1, item_start_y, column_width - 2, m_LineHeight - 1));
                }
                else {
                    CGContextSetFillColorWithColor(context, m_InactiveCursor.CGColor);
                    CGContextFillRect(context, NSMakeRect(start_x + 1, item_start_y, column_width - 2, m_LineHeight - 1));
                }
            }
            
            const ColoringAttrs& attrs = AttrsForItem(item, item_vd);
            const bool focused = m_State->CursorPos == i && active && wnd_active;
            NSRect rect = NSMakeRect(start_x + icon_size + 2*g_TextInsetsInLine[0],
                                     item_start_y + m_LineTextBaseline,
                                     column_width - icon_size - 2*g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                     /*m_FontHeight*/0);

            // Draw stats columns for specific views.
            int spec_col_x = m_ItemsArea.size.width;
            if (m_State->ViewType == PanelViewType::Full) {
                NSRect time_rect = NSMakeRect(spec_col_x - m_TimeColumnWidth + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              m_TimeColumnWidth - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);
                NSString *time_str = FormHumanReadableShortTime(item.MTime());
                NSDictionary *attr = focused ? attrs.focused_time : attrs.regular_time;
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
                NSString *date_str = FormHumanReadableShortDate(item.MTime());
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
            if(m_State->ViewType == PanelViewType::Wide || m_State->ViewType == PanelViewType::Full) {
                // draw the entry size on the right
                NSRect size_rect = NSMakeRect(spec_col_x - m_SizeColumWidth + g_TextInsetsInLine[0],
                                              rect.origin.y,
                                              m_SizeColumWidth - g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                                              rect.size.height);

                [FileSizeToString(item, item_vd) drawWithRect:size_rect
                                              options:0
                                           attributes:focused ? attrs.focused_size : attrs.regular_size];
                
                rect.size.width -= m_SizeColumWidth;
            }

            // Draw item text.
            NSDictionary *item_text_attr = focused ? attrs.focused : attrs.regular;
            
            if(rect.size.width > 0) {
                NSString *string = item.NSDisplayName();
                if( !is_listing_uniform && (m_State->ViewType == PanelViewType::Wide || m_State->ViewType == PanelViewType::Full) )
                    string = [NSString stringWithUTF8StdString:item.Path()];
                [string drawWithRect:rect options:0 attributes:item_text_attr];
            }
            
            // Draw icon
            NSImageRep *image_rep = m_IconCache.ImageFor(item, item_vd);
            NSRect icon_rect = NSMakeRect(start_x + g_TextInsetsInLine[0],
                                          item_start_y + floor((m_LineHeight - icon_size) / 2. - 0.5),
                                          icon_size,
                                          icon_size);
            [image_rep drawInRect:icon_rect
                         fromRect:NSZeroRect
                        operation:NSCompositeSourceOver
                         fraction:1.0
                   respectFlipped:YES
                            hints:nil];
            
            // Draw symlink arrow over an icon
            if(item.IsSymlink())
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
    if (m_State->ViewType == PanelViewType::Wide)
    {
        int x = m_ItemsArea.size.width - m_SizeColumWidth;
        NSPoint points[2] = {
            NSMakePoint(x + 0.5, m_ItemsArea.origin.y),
            NSMakePoint(x + 0.5, m_ItemsArea.origin.y + m_ItemsArea.size.height)
        };
        CGContextSetStrokeColorWithColor(context, m_ColumnDividerColor.CGColor);
        CGContextSetLineWidth(context, 1);
        CGContextStrokeLineSegments(context, points, 2);
    }
    else if (m_State->ViewType == PanelViewType::Full)
    {
        int x_pos[3];
        x_pos[0] = m_ItemsArea.size.width - m_TimeColumnWidth;
        x_pos[1] = x_pos[0] - m_DateColumnWidth;
        x_pos[2] = x_pos[1] - m_SizeColumWidth;
        for (int i = 0; i < 3; ++i)
        {
            int x = x_pos[i];
            NSPoint points[2] = {
                NSMakePoint(x + 0.5, m_ItemsArea.origin.y),
                NSMakePoint(x + 0.5, m_ItemsArea.origin.y + m_ItemsArea.size.height)
            };
            CGContextSetStrokeColorWithColor(context, m_ColumnDividerColor.CGColor);
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

const ModernPanelViewPresentation::ColoringAttrs& ModernPanelViewPresentation::AttrsForItem(const VFSListingItem& _item, const PanelData::PanelVolatileData& _item_vd) const
{
    size_t i = 0, e = m_ColoringRules.size();
    for(;i<e;++i)
        if(m_ColoringRules[i].filter.Filter(_item, _item_vd)) {
            assert(i < m_ColoringAttrs.size());
            return m_ColoringAttrs[i];
        }
    
    static ColoringAttrs dummy;
    return dummy;
}

void ModernPanelViewPresentation::CalculateLayoutFromFrame()
{
    m_ItemsArea.origin.x = 0;
    m_ItemsArea.origin.y = m_Header->Height();
    m_ItemsArea.size.height = floor(m_Size.height - m_Header->Height() - m_ItemsFooter->Height());
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
    const double icon_size    = m_IconCache.IconSize();
    
    il.whole_area.size.width    = column_width;
    il.whole_area.size.height   = row_height;
    
    il.icon = NSMakeRect(g_TextInsetsInLine[0], floor((m_LineHeight - icon_size) / 2. + 0.5),
                         icon_size, icon_size);
    
    NSRect filename_rect = NSMakeRect(icon_size + 2*g_TextInsetsInLine[0], 0,
                             column_width - icon_size - 2*g_TextInsetsInLine[0] - g_TextInsetsInLine[2],
                             m_FontInfo.LineHeight());
    if (m_State->ViewType == PanelViewType::Full)
        filename_rect.size.width -= m_TimeColumnWidth + m_DateColumnWidth;
    if(m_State->ViewType == PanelViewType::Wide || m_State->ViewType == PanelViewType::Full)
        filename_rect.size.width -= m_SizeColumWidth;
    if(filename_rect.size.width < 0)
        filename_rect.size.width = 0;
    
    il.filename_area = filename_rect;
    
    auto item = m_State->Data->EntryAtSortPosition(_item_index);
    if(!item)
        return il;
    
    if(filename_rect.size.width > 0) {
        // what for AttrsForItem is used here?
        NSRect rc = [item.NSDisplayName() boundingRectWithSize:filename_rect.size
                                                        options:0
                                                     attributes:AttrsForItem(item,
                                                                             m_State->Data->VolatileDataAtSortPosition(_item_index)).regular];
        
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
    m_IconCache.Flush();
}

double ModernPanelViewPresentation::GetSingleItemHeight()
{
    return m_LineHeight;
}

void ModernPanelViewPresentation::SetupFieldRenaming(NSScrollView *_editor, int _item_index)
{
    NSPoint origin = ItemOrigin(_item_index);
    NSRect rc = NSOffsetRect(LayoutItem(_item_index).filename_area, origin.x, origin.y);
    auto line_padding = 2.;
    rc.origin.x -= line_padding;
    rc.origin.y += /* g_TextInsetsInLine[1]*/ m_LineTextBaseline - m_FontInfo.Ascent();
    rc.size.width += line_padding;
    
    _editor.frame = rc;

    NSTextView *tv = _editor.documentView;
    tv.font = m_Font;
    tv.textContainerInset = NSMakeSize(0, 0);
    tv.textContainer.lineFragmentPadding = line_padding;
}

void ModernPanelViewPresentation::SetTrimming(PanelViewFilenameTrimming _mode)
{
    super::SetTrimming(_mode);
    BuildAppearance();
}
