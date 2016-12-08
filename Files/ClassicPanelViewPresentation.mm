//
//  ClassicPanelViewPresentation.cpp
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Utility/HexadecimalColor.h>
#include <Utility/Encodings.h>
#include <Utility/FontCache.h>
#include <Utility/ByteCountFormatter.h>
#include "ClassicPanelViewPresentation.h"
#include "OrthodoxMonospace.h"
#include "PanelView.h"
#include "PanelData.h"

/////////////////////////////////////////////////////////////////////////////////////////
// Helper functions and constants.
/////////////////////////////////////////////////////////////////////////////////////////

static const auto g_ConfigShowVolumeBar         = "filePanel.general.showVolumeInformationBar";
static const auto g_ConfigColoring              = "filePanel.classic.coloringRules_v1";
static const auto g_ConfigRegularBackground     = "filePanel.classic.regularBackground";
static const auto g_ConfigCursorBackground      = "filePanel.classic.cursorBackground";
static const auto g_ConfigTextColor             = "filePanel.classic.textColor";
static const auto g_ConfigActiveTextColor       = "filePanel.classic.activeTextColor";
static const auto g_ConfigHighlightTextColor    = "filePanel.classic.highlightTextColor";
static const auto g_ConfigFont                  = "filePanel.classic.font";

static char *strlefttrim(char *_s, char _c)
{
    int amount = 0;
    while(_s[amount] && _s[amount] == _c)
        amount++;
    if(!amount)
        return _s;
    memmove(_s, _s + amount, strlen(_s) - amount + 1);
    return _s;
}

static bool TimeFormatIsDayFirst()
{
    static bool day_first = true; // month is first overwise
    
    static once_flag once;
    call_once(once, []{
        // a very-very nasty code here - trying to parse Unicode Technical Standard #35 stuff in a quite naive way
        NSDateFormatter *dateFormatter = [NSDateFormatter new];
        dateFormatter.dateStyle = NSDateFormatterShortStyle;
        
        NSString *format = dateFormatter.dateFormat;
        const char *s = format.UTF8String;
        
        const char *m = strstr(s, "MM");
        if(m == nullptr)
            m = strstr(s, "M");
        
        const char *d = strstr(s, "dd");
        if(d == nullptr)
            d = strstr(s, "d");
        
        if(m < d)
            day_first = false;
    });
    
    return day_first;
}

static oms::StringBuf<14> FormHumanReadableTimeRepresentation(time_t _in)
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    if(TimeFormatIsDayFirst())
        sprintf(buf, "%2.2d.%2.2d.%2.2d %2.2d:%2.2d", tt.tm_mday, tt.tm_mon + 1, tt.tm_year % 100, tt.tm_hour, tt.tm_min);
    else
        sprintf(buf, "%2.2d.%2.2d.%2.2d %2.2d:%2.2d", tt.tm_mon + 1, tt.tm_mday, tt.tm_year % 100, tt.tm_hour, tt.tm_min);
    oms::StringBuf<14> r;
    r.FromChars((uint8_t*)buf, 14);
    return r;
}



static oms::StringBuf<8> FormHumanReadableDateRepresentation(time_t _in)
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    if(TimeFormatIsDayFirst())
        sprintf(buf, "%2.2d.%2.2d.%2.2d",
                tt.tm_mday,
                tt.tm_mon + 1,
                tt.tm_year % 100
                );
    else
        sprintf(buf, "%2.2d.%2.2d.%2.2d",
                tt.tm_mon + 1,
                tt.tm_mday,
                tt.tm_year % 100
                );
    oms::StringBuf<8> r;
    r.FromChars((uint8_t*)buf, 8);
    return r;
}

static void FormHumanReadableTimeRepresentation5(time_t _in, UniChar _out[5])
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    sprintf(buf, "%2.2d:%2.2d", tt.tm_hour, tt.tm_min);
    
    for(int i = 0; i < 5; ++i) _out[i] = buf[i];
}

oms::StringBuf<6> ClassicPanelViewPresentation::FormHumanReadableSizeRepresentation(unsigned long _sz) const
{
    unsigned short buf[6];
    int sz = ByteCountFormatter::Instance().ToUTF16(_sz, buf, 6, FileSizeFormat());
    assert(sz <= 6);
    oms::StringBuf<6> r;
    r.FromUniChars(buf, sz);
    if(r.Size() < 6)
        r.AddLeadingPaddingChars(' ', 6 - r.Size());
    return r;
}

oms::StringBuf<6> ClassicPanelViewPresentation::FormHumanReadableSizeReprentationForDirEnt(const VFSListingItem &_dirent, const PanelData::VolatileData& _vd) const
{
    if( _dirent.IsDir() ) {
        if( _vd.is_size_calculated() ) {
            return FormHumanReadableSizeRepresentation( _vd.size );
        }
        else {
            char buf[32];
            memset(buf, 0, sizeof(buf));
            if( !_dirent.IsDotDot()) {
                static string st = NSLocalizedString(@"__CLASSICPRESENTATION_FOLDER_WORD", "Fixed-length (6 chars) string for folders, for English is 'Folder'").UTF8String;
                strcpy(buf, st.c_str());
            }
            else {
                static string st = NSLocalizedString(@"__CLASSICPRESENTATION_UP_WORD", "Fixed-length (6 chars) string for upper-dir, for English is '    Up'").UTF8String;
                strcpy(buf, st.c_str());
            }
            oms::StringBuf<32> tmp;
            tmp.FromUTF8(buf, strlen(buf));
            oms::StringBuf<6> r;
            r.FromUniChars(tmp.Chars(), min(tmp.Size(), uint16_t(6)));
            return r;
        }
    }
    else {
        return FormHumanReadableSizeRepresentation(_dirent.Size());
    }
}

static oms::StringBuf<1> FormHumanReadableSortModeReprentation(PanelData::PanelSortMode::Mode _mode)
{
    char c;
    switch (_mode)
    {
        case PanelData::PanelSortMode::SortByName:     c='n'; break;
        case PanelData::PanelSortMode::SortByNameRev:  c='N'; break;
        case PanelData::PanelSortMode::SortByExt:      c='e'; break;
        case PanelData::PanelSortMode::SortByExtRev:   c='E'; break;
        case PanelData::PanelSortMode::SortBySize:     c='s'; break;
        case PanelData::PanelSortMode::SortBySizeRev:  c='S'; break;
        case PanelData::PanelSortMode::SortByModTime:    c='m'; break;
        case PanelData::PanelSortMode::SortByModTimeRev: c='M'; break;
        case PanelData::PanelSortMode::SortByBirthTime:    c='b'; break;
        case PanelData::PanelSortMode::SortByBirthTimeRev: c='B'; break;
        default:                                       c='?'; break;
    }
    oms::StringBuf<1> r;
    r.FromChars((uint8_t*)&c, 1);
    return r;
}

oms::StringBuf<256> ClassicPanelViewPresentation::FormHumanReadableBytesAndFiles(unsigned long _sz, int _total_files) const
{
    // TODO: localization support
    char buf_bytes[256];
    ByteCountFormatter::Instance().ToUTF8(_sz, (unsigned char*)buf_bytes, 256, SelectionSizeFormat());
    
    char buf[256] = {0};
    
    if(_total_files == 1) {
        static string fmt = " "s + NSLocalizedString(@"%s in 1 file", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes);
    }
    else if(_total_files == 2) {
        static string fmt = " "s + NSLocalizedString(@"%s in 2 files", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes);
    }
    else if(_total_files == 3) {
        static string fmt = " "s + NSLocalizedString(@"%s in 3 files", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes);
    }
    else if(_total_files == 4) {
        static string fmt = " "s + NSLocalizedString(@"%s in 4 files", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes);
    }
    else if(_total_files == 5) {
        static string fmt = " "s + NSLocalizedString(@"%s in 5 files", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes);
    }
    else if(_total_files == 6) {
        static string fmt = " "s + NSLocalizedString(@"%s in 6 files", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes);
    }
    else if(_total_files == 7) {
        static string fmt = " "s + NSLocalizedString(@"%s in 7 files", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes);
    }
    else if(_total_files == 8) {
        static string fmt = " "s + NSLocalizedString(@"%s in 8 files", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes);
    }
    else if(_total_files == 9) {
        static string fmt = " "s + NSLocalizedString(@"%s in 9 files", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes);
    }
    else {
        static string fmt = " "s + NSLocalizedString(@"%s in %d files", "Total files size in panel's bottom info bar").UTF8String + " "s;
        sprintf(buf, fmt.c_str(), buf_bytes, _total_files);
    }
    
    oms::StringBuf<256> out;
    out.FromUTF8(buf, strlen(buf));
    return out;
}

static oms::StringBuf<MAXPATHLEN> ComposeFooterFileNameForEntry(const VFSListingItem &_dirent, PanelViewType _view_type)
{   // output is a direct filename or symlink path in ->filename form
    oms::StringBuf<MAXPATHLEN> out;
    if(!_dirent.IsSymlink()) {
        if( _dirent.Listing()->IsUniform() ) // this looks like a hacky solution
            out.FromUTF8(_dirent.Filename()); // we're on regular panel - just use filename
        else {
            // we're on non-uniform panel like temporary, will return full path for short and medium view types
            if( _view_type == PanelViewType::Short || _view_type == PanelViewType::Medium )
                out.FromUTF8(_dirent.Path());
            else
                out.FromUTF8(_dirent.Filename());
        }
    }
    else if(_dirent.Symlink() != 0)
        {
            string str("->");
            str += _dirent.Symlink();
            out.FromUTF8(str);
        }
    if(out.CanBeComposed())
        out.NormalizeToFormC();
    return out;
}

/////////////////////////////////////////////////////////////////////////////////////////
// ClassicPanelViewPresentation class
/////////////////////////////////////////////////////////////////////////////////////////

ClassicPanelViewPresentation::ClassicPanelViewPresentation(PanelView *_parent_view, PanelViewState *_view_state):
    PanelViewPresentation(_parent_view, _view_state)
{
    BuildGeometry();
    BuildAppearance();
    
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigShowVolumeBar,        [=]{ OnGeometryOptionsChanged(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigFont,                 [=]{ OnGeometryOptionsChanged(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigColoring,             [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigRegularBackground,    [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigCursorBackground,     [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigTextColor,            [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigActiveTextColor,      [=]{ BuildAppearance(); }));
    m_ConfigObservations.emplace_back( GlobalConfig().Observe(g_ConfigHighlightTextColor,   [=]{ BuildAppearance(); }));
}

void ClassicPanelViewPresentation::OnGeometryOptionsChanged()
{
    BuildGeometry();
    CalcLayout(m_FrameSize);
    EnsureCursorIsVisible();
    SetViewNeedsDisplay();
}

void ClassicPanelViewPresentation::BuildGeometry()
{
    CTFontRef font = (CTFontRef)CFBridgingRetain([NSFont fontWithStringDescription:[NSString stringWithUTF8StdString:GlobalConfig().GetString(g_ConfigFont).value_or("")]]);
    if(!font) font = CTFontCreateWithName( CFSTR("Menlo Regular"), 15, 0);
    
    m_FontCache = FontCache::FontCacheFromFont(font);
    CFRelease(font);
    
    m_DrawVolumeInfo = GlobalConfig().GetBool(g_ConfigShowVolumeBar);
}

void ClassicPanelViewPresentation::BuildAppearance()
{
    m_BackgroundColor       = HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigRegularBackground).value_or(""));
    m_CursorBackgroundColor = HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigCursorBackground).value_or(""));
    m_TextColor             = HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigTextColor).value_or(""));
    m_ActiveTextColor       = HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigActiveTextColor).value_or(""));
    m_HighlightTextColor    = HexadecimalColorStringToRGBA(GlobalConfig().GetString(g_ConfigHighlightTextColor).value_or(""));
    
    // Coloring rules
    m_ColoringRules.clear();
    auto cr = GlobalConfig().Get(g_ConfigColoring);
    if( cr.IsArray() )
        for( auto i = cr.Begin(), e = cr.End(); i != e; ++i )
            m_ColoringRules.emplace_back( PanelViewPresentationItemsColoringRule::FromJSON(*i) );
    
    SetViewNeedsDisplay();    
}

DoubleColor ClassicPanelViewPresentation::GetDirectoryEntryTextColor(const VFSListingItem &_dirent, const PanelData::VolatileData& _vd, bool _is_focused)
{
    for(auto &r: m_ColoringRules)
        if(r.filter.Filter(_dirent, _vd))
            return _is_focused ? r.focused : r.regular;
    static DoubleColor def;
    return def;
}

void ClassicPanelViewPresentation::Draw(NSRect _dirty_rect)
{
    if (!m_State || !m_State->Data) return;
    assert(m_State->CursorPos < (int)m_State->Data->SortedDirectoryEntries().size());
    assert(m_State->ItemsDisplayOffset >= 0);
    
    CGContextRef context = (CGContextRef) NSGraphicsContext.currentContext.graphicsPort;
    
    // clear background
    m_BackgroundColor.Set(context);
    CGContextFillRect(context, NSRectToCGRect(_dirty_rect));
    
    DoDraw(context);
}

void ClassicPanelViewPresentation::CalcLayout(NSSize _from_px_size)
{
    m_FrameSize = _from_px_size;
    m_SymbHeight = m_FrameSize.height / m_FontCache->Height();
    m_SymbWidth = m_FrameSize.width / m_FontCache->Width();
    
    m_BytesInDirectoryVPos = m_SymbHeight-1;
    if(m_DrawVolumeInfo)
        m_BytesInDirectoryVPos--;
    m_EntryFooterVPos = m_BytesInDirectoryVPos - 1;
    m_SelectionVPos = m_EntryFooterVPos - 1;    
}

void ClassicPanelViewPresentation::OnFrameChanged(NSRect _frame)
{
    CalcLayout(_frame.size);
    EnsureCursorIsVisible();
}

NSRect ClassicPanelViewPresentation::GetItemColumnsRect()
{
    return NSMakeRect(0, m_FontCache->Height(),
                      m_FontCache->Width()*m_SymbWidth, m_FontCache->Height()*GetMaxItemsPerColumn());
}

int ClassicPanelViewPresentation::GetItemIndexByPointInView(CGPoint _point, PanelViewHitTest::Options _opt)
{
    // Developer defined constants.
    const int columns_max = 3;
    const int rows_start = 1;
    
    
    const int columns = GetNumberOfItemColumns();
    const int entries_in_column = GetMaxItemsPerColumn();
    
    CGPoint point_in_chars = NSMakePoint(_point.x/m_FontCache->Width(), _point.y/m_FontCache->Height());
    
    // Check if click is in files' view area, including horizontal bottom line.
    if (point_in_chars.y < rows_start || point_in_chars.y > rows_start + entries_in_column
        || point_in_chars.x < 0 || point_in_chars.x >= m_SymbWidth)
        return -1;
    
    // Calculate the number of visible files.
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    const int max_files_to_show = entries_in_column * columns;
    int visible_files = (int)sorted_entries.size() - m_State->ItemsDisplayOffset;
    if (visible_files > max_files_to_show) visible_files = max_files_to_show;
    
    // Calculate width of each column.
    const int column_width = (m_SymbWidth - 1) / columns;
    int columns_rest = m_SymbWidth - 1 - column_width*columns;
    int columns_width[columns_max] = {column_width, column_width, column_width};
    // Add 1 to the last column's with to include the right vertical view edge in hit test check
    // for that column.
    ++columns_width[columns - 1];
    if (columns == 3 && columns_rest)
    {
        columns_width[2]++;
        columns_rest--;
    }
    if (columns_rest)
    {
        columns_width[1]++;
        columns_rest--;
    }
    assert(columns_rest == 0);
    
    
    // Calculate cursor pos.
    int column = 0;
    if (point_in_chars.x > columns_width[0] + columns_width[1]) column = 2;
    else if (point_in_chars.x > columns_width[0]) column = 1;
    int row = point_in_chars.y - rows_start;
    if (row >= entries_in_column) row = entries_in_column - 1;
    int file_number =  row + column*entries_in_column;
    if (file_number >= visible_files)
        return -1;
    
    return m_State->ItemsDisplayOffset + file_number;
}

array<int, 3> ClassicPanelViewPresentation::ColumnWidthsShort() const
{
    const int columns = GetNumberOfItemColumns();
    int column_width = (m_SymbWidth - 1) / columns;
    int columns_rest = m_SymbWidth - 1 - column_width*columns;
    array<int, 3> columns_width{{column_width, column_width, column_width}};
    if(columns_rest) { columns_width[2]++; columns_rest--; }
    if(columns_rest) { columns_width[1]++; columns_rest--; }
    columns_width[0]--;
    columns_width[1]--;
    columns_width[2]--;
    return columns_width;    
}

array<int, 2> ClassicPanelViewPresentation::ColumnWidthsMedium() const
{
    const int columns = GetNumberOfItemColumns();
    int column_width = (m_SymbWidth - 1) / columns;
    int columns_rest = m_SymbWidth - 1 - column_width*columns;
    array<int, 2> columns_width{{column_width, column_width}};
    if(columns_rest) { columns_width[1]++; columns_rest--; }
    columns_width[0]--;
    columns_width[1]--;
    return columns_width;
}

array<int, 4> ClassicPanelViewPresentation::ColumnWidthsFull() const
{
    array<int, 4> columns_width{{m_SymbWidth - 23, 6, 8, 5}};
    columns_width[0]--;
    if(columns_width[0] < 0) columns_width[0] = 0;
    return columns_width;
}

array<int, 2> ClassicPanelViewPresentation::ColumnWidthsWide() const
{
    array<int, 2> columns_width{{m_SymbWidth - 8, 6}};
    columns_width[0]--;
    if(columns_width[0] < 0) columns_width[0] = 0;
    return columns_width;
}

NSRect ClassicPanelViewPresentation::ItemRect(int _item_index) const
{
    const int columns = GetNumberOfItemColumns();
    const int entries_in_column = GetMaxItemsPerColumn();
    const int max_files_to_show = entries_in_column * columns;
    if(_item_index < m_State->ItemsDisplayOffset)
        return NSMakeRect(0, 0, -1, -1);
    const int scrolled_index = _item_index - m_State->ItemsDisplayOffset;
    if(scrolled_index >= max_files_to_show)
        return NSMakeRect(0, 0, -1, -1);
    const int column = scrolled_index / entries_in_column;
    const int row = scrolled_index % entries_in_column;
    
    int Y = row + 1;
    int X = 1, W = 0;
    if( m_State->ViewType == PanelViewType::Short ) {
        auto widths = ColumnWidthsShort();
        for(int i = 0; i < column; ++i)
            X += widths[i] + 1;
        W = widths[column];
    }
    else if(m_State->ViewType == PanelViewType::Medium) {
        auto widths = ColumnWidthsMedium();
        for(int i = 0; i < column; ++i)
            X += widths[i] + 1;
        W = widths[column];
    }
    else if( m_State->ViewType == PanelViewType::Full )
        W = m_SymbWidth - 2;
    else if( m_State->ViewType == PanelViewType::Wide )
        W = m_SymbWidth - 2;
    
    return NSMakeRect(X*m_FontCache->Width(),
                      Y*m_FontCache->Height(),
                      W*m_FontCache->Width(),
                      m_FontCache->Height());
}

NSRect ClassicPanelViewPresentation::ItemFilenameRect(int _item_index) const
{
    const int columns = GetNumberOfItemColumns();
    const int entries_in_column = GetMaxItemsPerColumn();
    const int max_files_to_show = entries_in_column * columns;
    if(_item_index < m_State->ItemsDisplayOffset)
        return NSMakeRect(0, 0, -1, -1);
    const int scrolled_index = _item_index - m_State->ItemsDisplayOffset;
    if(scrolled_index >= max_files_to_show)
        return NSMakeRect(0, 0, -1, -1);
    const int column = scrolled_index / entries_in_column;
    const int row = scrolled_index % entries_in_column;
    
    int Y = row + 1;
    int X = 1, W = 0;
    if( m_State->ViewType == PanelViewType::Short ) {
        auto widths = ColumnWidthsShort();
        for(int i = 0; i < column; ++i)
            X += widths[i] + 1;
        W = widths[column];
    }
    else if(m_State->ViewType == PanelViewType::Medium) {
        auto widths = ColumnWidthsMedium();
        for(int i = 0; i < column; ++i)
            X += widths[i] + 1;
        W = widths[column];
    }
    else if( m_State->ViewType == PanelViewType::Full )
        W = ColumnWidthsFull()[0];
    else if( m_State->ViewType == PanelViewType::Wide )
        W = ColumnWidthsWide()[0];
    
    return NSMakeRect(X*m_FontCache->Width(),
                      Y*m_FontCache->Height(),
                      W*m_FontCache->Width(),
                      m_FontCache->Height());
}

int ClassicPanelViewPresentation::GetMaxItemsPerColumn() const
{
    int headers_and_footers = 4;
    if(m_DrawVolumeInfo)
        headers_and_footers++;
    return m_SymbHeight - headers_and_footers;
}

int ClassicPanelViewPresentation::Granularity()
{
    return m_FontCache->Width();
}

static function<void(oms::StringBuf<MAXPATHLEN> &_fn, int _width)> TrimmingFunction(PanelViewFilenameTrimming _method)
{
    if( _method == PanelViewFilenameTrimming::Heading)
        return [](oms::StringBuf<MAXPATHLEN> &_fn, int _width) { _fn.TrimEllipsisLeft( _width ); };
    if( _method == PanelViewFilenameTrimming::Middle )
        return [](oms::StringBuf<MAXPATHLEN> &_fn, int _width) { _fn.TrimEllipsisMiddle(_width); };
    return [](oms::StringBuf<MAXPATHLEN> &_fn, int _width) { _fn.TrimRight(_width); };
}

void ClassicPanelViewPresentation::DoDraw(CGContextRef context)
{
    // layout preparation
    const int columns = GetNumberOfItemColumns();
    int entries_in_column = GetMaxItemsPerColumn();
    int max_files_to_show = entries_in_column * columns;
    int column_width = (m_SymbWidth - 1) / columns;
    if(m_State->ViewType==PanelViewType::Wide) column_width = m_SymbWidth - 8;
    int columns_rest = m_SymbWidth - 1 - column_width*columns;
    int columns_width[] = {column_width, column_width, column_width};
    if(m_State->ViewType==PanelViewType::Short && columns_rest) { columns_width[2]++;  columns_rest--; }
    if(columns_rest) { columns_width[1]++;  columns_rest--; }
    
    int full_fn_column_width = m_SymbWidth - 23; if(full_fn_column_width < 0) full_fn_column_width = 0;
    int full_columns_width[] = {full_fn_column_width, 6, 8, 5};
    int full_column_fr_pos[] = {full_columns_width[0],
        full_columns_width[0] + full_columns_width[1] + 1,
        full_columns_width[0] + full_columns_width[1] + full_columns_width[2] + 2};
    
    const auto sorted_entries_size = m_State->Data->SortedDirectoryEntries().size();
    const bool is_listing_uniform = m_State->Data->Listing().IsUniform();
    int path_name_start_pos = 0, path_name_end_pos = 0;
    int selected_bytes_start_pos = 0, selected_bytes_end_pos = 0;
    int bytes_in_dir_start_pos = 0, bytes_in_dir_end_pos = 0;
    int volume_info_start_pos = 0, volume_info_end_pos = 0;
    auto fontcache = m_FontCache.get();
    
    oms::Context omsc(context, fontcache);

    const auto trim_panel_fn = TrimmingFunction(Trimming());
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw file names
    omsc.SetupForText();
    oms::StringBuf<MAXPATHLEN> fn;
    for(int n = 0, i = m_State->ItemsDisplayOffset;
        n < max_files_to_show && i < sorted_entries_size;
        ++n, ++i) {
        auto current = m_State->Data->EntryAtSortPosition(i);
        assert( current );
        auto current_vd = m_State->Data->VolatileDataAtSortPosition(i);
        
        if( is_listing_uniform || m_State->ViewType == PanelViewType::Short || m_State->ViewType == PanelViewType::Medium ) {
            if(current.CFDisplayName() == current.CFName())
                // entry has no altered display name, so just use it's real filename
                fn.FromUTF8(current.Name(), current.NameLen());
            else
                // entry is localized, load buffer from given display name
                fn.FromCFString(current.CFDisplayName());
        }
        else
            fn.FromUTF8( current.Path() );
        
        if(fn.CanBeComposed())// <-- this check usually takes 100-300 nanoseconds per filename
            fn.NormalizeToFormC();
            // ^^^^^^^^^^^^^^^^
            // long way to go - perform on-the-fly unicode normalization to form C
            // takes usually ~5microseconds on my 2012 mbp i7.
            // so it can take at max 5*100 filenames on screen = 500 microseconds, ie 0,5 millisecond per panel draw
            // can just forgive this overhead.

        int CN = n / entries_in_column;
        int Y = (n % entries_in_column + 1);
        int X = 1;
        for(int col_i = 0; col_i < CN; ++col_i) X += columns_width[col_i];
        
        bool focused = (i == m_State->CursorPos) && View().active;
        auto text_color = GetDirectoryEntryTextColor(current, current_vd, focused);
        
        if(m_State->ViewType != PanelViewType::Full) {
            if(focused)
                omsc.DrawBackground(m_CursorBackgroundColor, X, Y, columns_width[CN] - 1);
        
            trim_panel_fn(fn, columns_width[CN] - 1);
            omsc.DrawString(fn.Chars(), 0, fn.MaxForSpaceLeft(columns_width[CN] - 1), X, Y, text_color);
        
            if(m_State->ViewType==PanelViewType::Wide) {
                // draw entry size on right side, only for this mode
                auto size_info = FormHumanReadableSizeReprentationForDirEnt(current, current_vd);
            
                if(focused)
                    omsc.DrawBackground(m_CursorBackgroundColor, columns_width[0]+1, Y, size_info.Capacity);
            
                omsc.DrawString(size_info.Chars(), 0, size_info.Capacity, columns_width[0]+1, Y, text_color);
            }
        }
        else {
            UniChar time_info[5];
            auto size_info = FormHumanReadableSizeReprentationForDirEnt(current, current_vd);
            auto date_info = FormHumanReadableDateRepresentation(current.MTime());
            FormHumanReadableTimeRepresentation5(current.MTime(), time_info);
            
            if(focused) {
                if(full_columns_width[0] > 0)
                    omsc.DrawBackground(m_CursorBackgroundColor, X, Y, full_columns_width[0] - 1);
                omsc.DrawBackground(m_CursorBackgroundColor, 1 + full_column_fr_pos[0], Y, 6);
                omsc.DrawBackground(m_CursorBackgroundColor, 1 + full_column_fr_pos[1], Y, 8);
                omsc.DrawBackground(m_CursorBackgroundColor, 1 + full_column_fr_pos[2], Y, 5);
            }
            
            if(full_columns_width[0] > 0) {
                trim_panel_fn(fn, full_columns_width[0] - 1);
                omsc.DrawString(fn.Chars(), 0, fn.MaxForSpaceLeft(full_columns_width[0] - 1), X, Y, text_color);
            }
            omsc.DrawString(size_info.Chars(), 0, size_info.Capacity, 1 + full_column_fr_pos[0], Y, text_color);
            omsc.DrawString(date_info.Chars(), 0, date_info.Capacity, 1 + full_column_fr_pos[1], Y, text_color);
            omsc.DrawString(time_info, 0, 5, 1 + full_column_fr_pos[2], Y, text_color);
        }
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw header and footer data
    {
        auto current_entry = m_State->Data->EntryAtSortPosition( m_State->CursorPos );
        
        oms::StringBuf<14> time_info;
        oms::StringBuf<6> size_info;
        oms::StringBuf<MAXPATHLEN> footer_entry;
        auto sort_mode = FormHumanReadableSortModeReprentation(m_State->Data->SortMode().sort);
        if(current_entry) {
            time_info = FormHumanReadableTimeRepresentation( current_entry.MTime() );
            size_info = FormHumanReadableSizeReprentationForDirEnt( current_entry, m_State->Data->VolatileDataAtSortPosition(m_State->CursorPos) );
            footer_entry = ComposeFooterFileNameForEntry( current_entry, m_State->ViewType );
        }
        
        // draw sorting mode in left-upper corner
        oms::DrawSingleUniCharXY(sort_mode.Chars()[0], 1, 0, context, fontcache, m_HighlightTextColor);
        
        if(m_SymbWidth > 14) { // need to draw a path name on header
            oms::StringBuf<MAXPATHLEN*2> path;
            path.FromCFString( (__bridge CFStringRef)View().headerTitle );
            if(path.CanBeComposed())
                path.NormalizeToFormC();
            path.TrimEllipsisLeft(m_SymbWidth - 7);
            
            int symbs = path.Space() + 2;
            path_name_start_pos = (m_SymbWidth-symbs) / 2;
            path_name_end_pos = path_name_start_pos + symbs;
            
            if(View().active)
                omsc.DrawBackground(m_CursorBackgroundColor, path_name_start_pos, 0, symbs);
                
            omsc.DrawString(path.Chars(), 0, path.Size(), path_name_start_pos+1, 0, View().active ? m_ActiveTextColor : m_TextColor);
        }

        // entry footer info
        if(current_entry && m_State->ViewType != PanelViewType::Full)
        {
            if(m_SymbWidth > 2 + 14 + 6)
            {   // draw current entry time info, size info and maybe filename
                int Y = m_EntryFooterVPos;
                omsc.DrawString(time_info.Chars(), 0, time_info.Capacity, m_SymbWidth - 15, Y, m_TextColor);
                omsc.DrawString(size_info.Chars(), 0, size_info.Capacity, m_SymbWidth - 15 - 7, Y, m_TextColor);
                
                int symbs_for_name = m_SymbWidth - 2 - 14 - 6 - 2;
                if(symbs_for_name > 0) {
                    auto chars = footer_entry.MaxForSpaceRight(symbs_for_name);
                    omsc.DrawString(footer_entry.Chars(), chars.loc, chars.len, 1, Y, m_TextColor);
                }
            }
            else if(m_SymbWidth >= 2 + 6)
            {   // draw current entry size info and maybe time info
                int Y = m_EntryFooterVPos;
                omsc.DrawString(size_info.Chars(), 0, size_info.Capacity, 1, Y, m_TextColor);
                int symbs_for_name = m_SymbWidth - 2 - 6 - 1;
                if(symbs_for_name > 0)
                    omsc.DrawString(time_info.Chars(), 0, time_info.MaxForSpaceLeft(symbs_for_name), 8, Y, m_TextColor);
            }
        }
        else if(current_entry)
        {
            auto chars = footer_entry.MaxForSpaceRight(m_SymbWidth-2);
            omsc.DrawString(footer_entry.Chars(), chars.loc, chars.len, 1, m_EntryFooterVPos, m_TextColor);
        }
        
        if(m_State->Data->Stats().selected_entries_amount != 0 && m_SymbWidth > 14)
        { // process selection if any
            auto str = FormHumanReadableBytesAndFiles(m_State->Data->Stats().bytes_in_selected_entries, m_State->Data->Stats().selected_entries_amount);
            str.TrimEllipsisLeft(m_SymbWidth - 2);
            
            int symbs = str.Space();
            selected_bytes_start_pos = (m_SymbWidth-symbs) / 2;
            selected_bytes_end_pos   = selected_bytes_start_pos + symbs;
            omsc.DrawBackground(m_CursorBackgroundColor, selected_bytes_start_pos, m_SelectionVPos, symbs);
            omsc.DrawString(str.Chars(), 0, str.Size(), selected_bytes_start_pos, m_SelectionVPos, m_HighlightTextColor);
        }
        
        if(m_SymbWidth > 14)
        { // process bytes in directory
            auto str = FormHumanReadableBytesAndFiles(m_State->Data->Stats().bytes_in_raw_reg_files, (int)m_State->Data->Stats().raw_reg_files_amount);
            str.TrimEllipsisLeft(m_SymbWidth - 2);
            
            int symbs = str.Space();
            bytes_in_dir_start_pos = (m_SymbWidth-symbs) / 2;
            bytes_in_dir_end_pos   = bytes_in_dir_start_pos + symbs;
            omsc.DrawString(str.Chars(), 0, str.Size(), bytes_in_dir_start_pos, m_BytesInDirectoryVPos, m_TextColor);
        }
        
        if(m_DrawVolumeInfo && m_SymbWidth > 14)
        {
            char bytes[256], buf[1024];
            UpdateStatFS();
            ByteCountFormatter::Instance().ToUTF8(StatFS().avail_bytes, (unsigned char*)bytes, 256, ByteCountFormatter::Adaptive6);
            static string fmt = " "s + NSLocalizedString(@"%s: %s available", "Volume information bar, showing volume name and free space").UTF8String + " "s;
            sprintf(buf, fmt.c_str(), StatFS().volume_name.c_str(), bytes);
            oms::StringBuf<1024> str;
            str.FromUTF8(buf, strlen(buf));
            str.TrimEllipsisLeft(m_SymbWidth - 2);
            
            int symbs = str.Space();
            volume_info_start_pos = (m_SymbWidth-symbs) / 2;
            volume_info_end_pos   = volume_info_start_pos + symbs;
            omsc.DrawString(str.Chars(), 0, str.Size(), volume_info_start_pos, m_SymbHeight-1, m_TextColor);
        }
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw frames
    omsc.SetupForASCIIArt();
    omsc.SetFillColor(m_TextColor);
    oms::unichars_draw_batch b;
    
    for(int i = 1; i < m_SymbHeight - 1; ++i)
    {
        uint16_t l[] = {u'║', u'╟', u'╠'};
        uint16_t r[] = {u'║', u'╢', u'╣'};
        int n = 0;
        if(i == m_SelectionVPos) n = 1;
        else if(m_DrawVolumeInfo && i == m_BytesInDirectoryVPos) n = 2;
        b.put(l[n], 0, i);
        b.put(r[n], m_SymbWidth-1, i);
    }
    b.put(u'╔', 0, 0);
    b.put(u'╚', 0, m_SymbHeight-1);
    b.put(u'╝', m_SymbWidth-1, m_SymbHeight-1);
    b.put(u'╗', m_SymbWidth-1, 0);
    for(int i = 1; i < m_SelectionVPos; ++i)
    {
        if(m_State->ViewType != PanelViewType::Full)
            b.put(u'│', columns_width[0], i);
        if(m_State->ViewType == PanelViewType::Short)
            b.put(u'│', columns_width[0]+columns_width[1], i);
        else if(m_State->ViewType == PanelViewType::Full) {
            if(full_column_fr_pos[0] > 0)
                b.put(u'│', full_column_fr_pos[0], i);
            if(full_column_fr_pos[1] > 0)
                b.put(u'│', full_column_fr_pos[1], i);
            if(full_column_fr_pos[2] > 0)
                b.put(u'│', full_column_fr_pos[2], i);
        }
    }
    for(int i = 1; i < m_SymbWidth - 1; ++i)
    {
        bool is_col = false;
        if(m_State->ViewType != PanelViewType::Full &&
           ((i == columns_width[0]) || (i == columns_width[0] + columns_width[1])))
            is_col = true;
        else if(m_State->ViewType == PanelViewType::Full &&
            ((i == full_column_fr_pos[0]) || (i == full_column_fr_pos[1]) || (i == full_column_fr_pos[2])))
            is_col = true;
        
        if(!is_col)
        {
            if( (i!=1) && (i < path_name_start_pos || i >= path_name_end_pos))
                b.put(u'═', i, 0);
            if(i < selected_bytes_start_pos || i >= selected_bytes_end_pos )
                b.put(u'─', i, m_SelectionVPos);
        }
        else
        {
            if(i < selected_bytes_start_pos || i >= selected_bytes_end_pos )
                b.put(u'┴', i, m_SelectionVPos);
            if( (i!=1) && (i < path_name_start_pos || i>= path_name_end_pos) )
                b.put(u'╤', i, 0);
        }
        if(i < bytes_in_dir_start_pos || i >= bytes_in_dir_end_pos)
            b.put(u'═', i, m_BytesInDirectoryVPos);
        if(m_DrawVolumeInfo && (i < volume_info_start_pos || i >= volume_info_end_pos))
            b.put(u'═', i, m_SymbHeight - 1);
    }
    oms::DrawUniCharsXY(b, context, fontcache);
}

double ClassicPanelViewPresentation::GetSingleItemHeight()
{
    return m_FontCache->Height();
}

void ClassicPanelViewPresentation::SetupFieldRenaming(NSScrollView *_editor, int _item_index)
{
    auto line_padding = 2.;
    NSRect rc = ItemFilenameRect(_item_index);
    rc.origin.x -= line_padding;
    rc.size.width += line_padding;
    
    _editor.frame = rc;
    
    NSTextView *tv = _editor.documentView;
    tv.font = (__bridge NSFont*) m_FontCache->BaseFont();
    tv.textContainerInset = NSMakeSize(0, 0);
    tv.textContainer.lineFragmentPadding = line_padding;
}
