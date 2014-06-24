//
//  ClassicPanelViewPresentation.cpp
//  Files
//
//  Created by Pavel Dogurevich on 06.05.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "ClassicPanelViewPresentation.h"

#import "OrthodoxMonospace.h"
#import "Encodings.h"
#import "PanelView.h"
#import "PanelData.h"
#import "FontExtras.h"
#import "FontCache.h"
#import "NSUserDefaults+myColorSupport.h"
#import "ObjcToCppObservingBridge.h"

/////////////////////////////////////////////////////////////////////////////////////////
// Helper functions and constants.
/////////////////////////////////////////////////////////////////////////////////////////

static bool TimeFormatIsDayFirst()
{
    static bool day_first = true; // month is first overwise
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
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

// _out will be _not_ null-terminated, just a raw buffer
static void FormHumanReadableTimeRepresentation14(time_t _in, UniChar _out[14])
{
    struct tm tt;
    localtime_r(&_in, &tt);
    
    char buf[32];
    if(TimeFormatIsDayFirst())
        sprintf(buf, "%2.2d.%2.2d.%2.2d %2.2d:%2.2d",
                tt.tm_mday,
                tt.tm_mon + 1,
                tt.tm_year % 100,
                tt.tm_hour,
                tt.tm_min
                );
    else
        sprintf(buf, "%2.2d.%2.2d.%2.2d %2.2d:%2.2d",
                tt.tm_mon + 1,
                tt.tm_mday,
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

static void FormHumanReadableSizeReprentationForDirEnt6(const VFSListingItem &_dirent, UniChar _out[6])
{
    if( _dirent.IsDir() )
    {
        if( _dirent.Size() != VFSListingItem::InvalidSize)
        {
            FormHumanReadableSizeRepresentation6(_dirent.Size(), _out);
        }
        else
        {
            char buf[32];
            memset(buf, 0, sizeof(buf));
            
            if( !_dirent.IsDotDot()) strcpy(buf, "Folder");
            else                      strcpy(buf, "    Up");
            
            for(int i = 0; i < 6; ++i) _out[i] = buf[i];
        }
    }
    else
    {
        FormHumanReadableSizeRepresentation6(_dirent.Size(), _out);
    }
}

static void FormHumanReadableSortModeReprentation1(PanelSortMode::Mode _mode, UniChar _out[1])
{
    switch (_mode)
    {
        case PanelSortMode::SortByName:     _out[0]='n'; break;
        case PanelSortMode::SortByNameRev:  _out[0]='N'; break;
        case PanelSortMode::SortByExt:      _out[0]='e'; break;
        case PanelSortMode::SortByExtRev:   _out[0]='E'; break;
        case PanelSortMode::SortBySize:     _out[0]='s'; break;
        case PanelSortMode::SortBySizeRev:  _out[0]='S'; break;
        case PanelSortMode::SortByMTime:    _out[0]='m'; break;
        case PanelSortMode::SortByMTimeRev: _out[0]='M'; break;
        case PanelSortMode::SortByBTime:    _out[0]='b'; break;
        case PanelSortMode::SortByBTimeRev: _out[0]='B'; break;
        default:                            _out[0]='?'; break;
    }
}

static void FormHumanReadableDirStatInfo32(unsigned long _sz, int _total_files, UniChar _out[32], size_t &_symbs)
{
    char buf[32];
    
    if(_sz < 1000000) // bytes
    {
        sprintf(buf, "%ld(%d)", _sz, _total_files);
    }
    else if(_sz < 9999lu * 1024lu) // kilobytes
    {
        unsigned long div = 1024lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%ldK(%d)", res + (_sz - res * div) / (div/2), _total_files);
    }
    else if(_sz < 9999lu * 1048576lu) // megabytes
    {
        unsigned long div = 1048576lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%ldM(%d)", res + (_sz - res * div) / (div/2), _total_files);
    }
    else if(_sz < 9999lu * 1073741824lu) // gigabytes
    {
        unsigned long div = 1073741824lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%ldG(%d)", res + (_sz - res * div) / (div/2), _total_files);
    }
    else if(_sz < 9999lu * 1099511627776lu) // terabytes
    {
        unsigned long div = 1099511627776lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%ldT(%d)", res + (_sz - res * div) / (div/2), _total_files);
    }
    else if(_sz < 9999lu * 1125899906842624lu) // petabytes
    {
        unsigned long div = 1125899906842624lu;
        unsigned long res = _sz / div;
        sprintf(buf, "%ldP(%d)", res + (_sz - res * div) / (div/2), _total_files);
    }
    else memset(buf, 0, 32);
    
    memset(_out, 0, sizeof(UniChar)*32);
    size_t s = strlen(buf);
    for(int i =0; i < s; ++i)
        _out[i] = buf[i];
    _symbs = s;
}

static void FormReadableBytes(unsigned long _sz, char buf[128])
{
#define __1000_1(a) ( (a) % 1000lu )
#define __1000_2(a) __1000_1( (a)/1000lu )
#define __1000_3(a) __1000_1( (a)/1000000lu )
#define __1000_4(a) __1000_1( (a)/1000000000lu )
#define __1000_5(a) __1000_1( (a)/1000000000000lu )
    if(_sz < 1000lu)
        sprintf(buf, "%lu", _sz);
    else if(_sz < 1000lu * 1000lu)
        sprintf(buf, "%lu %03lu", __1000_2(_sz), __1000_1(_sz));
    else if(_sz < 1000lu * 1000lu * 1000lu)
        sprintf(buf, "%lu %03lu %03lu", __1000_3(_sz), __1000_2(_sz), __1000_1(_sz));
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu)
        sprintf(buf, "%lu %03lu %03lu %03lu", __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz));
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu * 1000lu)
        sprintf(buf, "%lu %03lu %03lu %03lu %03lu", __1000_5(_sz), __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz));
#undef __1000_1
#undef __1000_2
#undef __1000_3
#undef __1000_4
#undef __1000_5
}

static void FormHumanReadableBytesAndFiles128(unsigned long _sz, int _total_files, uint16_t _out[128], size_t &_symbs, bool _space_prefix_and_postfix)
{
    // TODO: localization support
    char buf[128] = {0};
    char buf1[128] = {0};
    const char *postfix = _total_files > 1 ? "files" : "file";
    const char *space = _space_prefix_and_postfix ? " " : "";
    FormReadableBytes(_sz, buf1);
    sprintf(buf, "%s%s bytes in %d %s%s", space, buf1, _total_files, postfix, space);
    _symbs = strlen(buf);
    for(int i = 0; i < _symbs; ++i) _out[i] = buf[i];
}

static void ComposeFooterFileNameForEntry(const VFSListingItem &_dirent, uint16_t _buff[256], size_t &_sz)
{   // output is a direct filename or symlink path in ->filename form
    if(!_dirent.IsSymlink())
    {
        InterpretUTF8BufferAsUTF16( (unsigned char*) _dirent.Name(), _dirent.NameLen(), _buff, &_sz, 0xFFFD);
    }
    else
    {
        if(_dirent.Symlink() != 0)
        {
            _buff[0]='-';
            _buff[1]='>';
            InterpretUTF8BufferAsUTF16( (unsigned char*)_dirent.Symlink(), strlen(_dirent.Symlink()), _buff+2, &_sz, 0xFFFD);
            _sz += 2;
        }
        else
        {
            _sz = 0; // fallback case
        }
    }
}


/////////////////////////////////////////////////////////////////////////////////////////
// ClassicPanelViewPresentation class
/////////////////////////////////////////////////////////////////////////////////////////

ClassicPanelViewPresentation::ClassicPanelViewPresentation()
{
    BuildGeometry();
    BuildAppearance();

    m_GeometryObserver = [ObjcToCppObservingBlockBridge
                          bridgeWithObject:NSUserDefaults.standardUserDefaults
                          forKeyPaths:@[@"FilePanelsClassicFont", @"FilePanelsGeneralShowVolumeInformationBar"]
                          options:0
                          block:^(NSString *_key_path, id _objc_object, NSDictionary *_changed) {
                              BuildGeometry();
                              CalcLayout(m_FrameSize);
                              EnsureCursorIsVisible();
                              SetViewNeedsDisplay();
                          }];

    m_AppearanceObserver = [ObjcToCppObservingBlockBridge
                            bridgeWithObject:NSUserDefaults.standardUserDefaults
                            forKeyPaths:@[@"FilePanelsClassicBackgroundColor",
                                          @"FilePanelsClassicCursorBackgroundColor",
                                          @"FilePanelsClassicRegularFileColor",
                                          @"FilePanelsClassicFocusedRegularFileColor",
                                          @"FilePanelsClassicDirectoryColor",
                                          @"FilePanelsClassicFocusedDirectoryColor",
                                          @"FilePanelsClassicHiddenColor",
                                          @"FilePanelsClassicFocusedHiddenColor",
                                          @"FilePanelsClassicSelectedColor",
                                          @"FilePanelsClassicFocusedSelectedColor",
                                          @"FilePanelsClassicOtherColor",
                                          @"FilePanelsClassicFocusedOtherColor"]
                            options:0
                            block:^(NSString *_key_path, id _objc_object, NSDictionary *_changed) {
                                BuildAppearance();
                                SetViewNeedsDisplay();
                            }];
}

void ClassicPanelViewPresentation::BuildGeometry()
{
    CTFontRef font = (CTFontRef)CFBridgingRetain([NSUserDefaults.standardUserDefaults fontForKey:@"FilePanelsClassicFont"]);
    if(!font) font = CTFontCreateWithName( CFSTR("Menlo Regular"), 15, 0);
    
    m_FontCache = FontCache::FontCacheFromFont(font);
    CFRelease(font);
    
    m_DrawVolumeInfo = [NSUserDefaults.standardUserDefaults boolForKey:@"FilePanelsGeneralShowVolumeInformationBar"];
}

void ClassicPanelViewPresentation::BuildAppearance()
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;

    m_BackgroundColor       = DoubleColor([defaults colorForKey:@"FilePanelsClassicBackgroundColor"]);
    m_CursorBackgroundColor = DoubleColor([defaults colorForKey:@"FilePanelsClassicCursorBackgroundColor"]);
    m_RegularFileColor[0]   = DoubleColor([defaults colorForKey:@"FilePanelsClassicRegularFileColor"]);
    m_RegularFileColor[1]   = DoubleColor([defaults colorForKey:@"FilePanelsClassicFocusedRegularFileColor"]);
    m_DirectoryColor[0]     = DoubleColor([defaults colorForKey:@"FilePanelsClassicDirectoryColor"]);
    m_DirectoryColor[1]     = DoubleColor([defaults colorForKey:@"FilePanelsClassicFocusedDirectoryColor"]);
    m_HiddenColor[0]        = DoubleColor([defaults colorForKey:@"FilePanelsClassicHiddenColor"]);
    m_HiddenColor[1]        = DoubleColor([defaults colorForKey:@"FilePanelsClassicFocusedHiddenColor"]);
    m_SelectedColor[0]      = DoubleColor([defaults colorForKey:@"FilePanelsClassicSelectedColor"]);
    m_SelectedColor[1]      = DoubleColor([defaults colorForKey:@"FilePanelsClassicFocusedSelectedColor"]);
    m_OtherColor[0]         = DoubleColor([defaults colorForKey:@"FilePanelsClassicOtherColor"]);
    m_OtherColor[1]         = DoubleColor([defaults colorForKey:@"FilePanelsClassicFocusedOtherColor"]);
}

const DoubleColor& ClassicPanelViewPresentation::GetDirectoryEntryTextColor(const VFSListingItem &_dirent, bool _is_focused)
{    
    if(_dirent.CFIsSelected()) return m_SelectedColor[_is_focused ? 1 : 0];
    if(_dirent.IsHidden()) return m_HiddenColor[_is_focused ? 1 : 0];
    if(_dirent.IsReg() || _dirent.IsDotDot()) return m_RegularFileColor[_is_focused ? 1 : 0];
    if(_dirent.IsDir()) return m_DirectoryColor[_is_focused ? 1 : 0];
    return m_OtherColor[_is_focused ? 1 : 0];
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

int ClassicPanelViewPresentation::GetItemIndexByPointInView(CGPoint _point)
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
    if( m_State->ViewType == PanelViewType::ViewShort ) {
        auto widths = ColumnWidthsShort();
        for(int i = 0; i < column; ++i)
            X += widths[i] + 1;
        W = widths[column];
    }
    else if(m_State->ViewType == PanelViewType::ViewMedium) {
        auto widths = ColumnWidthsMedium();
        for(int i = 0; i < column; ++i)
            X += widths[i] + 1;
        W = widths[column];
    }
    else if( m_State->ViewType == PanelViewType::ViewFull )
        W = m_SymbWidth - 2;
    else if( m_State->ViewType == PanelViewType::ViewWide )
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
    if( m_State->ViewType == PanelViewType::ViewShort ) {
        auto widths = ColumnWidthsShort();
        for(int i = 0; i < column; ++i)
            X += widths[i] + 1;
        W = widths[column];
    }
    else if(m_State->ViewType == PanelViewType::ViewMedium) {
        auto widths = ColumnWidthsMedium();
        for(int i = 0; i < column; ++i)
            X += widths[i] + 1;
        W = widths[column];
    }
    else if( m_State->ViewType == PanelViewType::ViewFull )
        W = ColumnWidthsFull()[0];
    else if( m_State->ViewType == PanelViewType::ViewWide )
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

void ClassicPanelViewPresentation::DoDraw(CGContextRef context)
{
    // layout preparation
    const int columns = GetNumberOfItemColumns();
    int entries_in_column = GetMaxItemsPerColumn();
    int max_files_to_show = entries_in_column * columns;
    int column_width = (m_SymbWidth - 1) / columns;
    if(m_State->ViewType==PanelViewType::ViewWide) column_width = m_SymbWidth - 8;
    int columns_rest = m_SymbWidth - 1 - column_width*columns;
    int columns_width[] = {column_width, column_width, column_width};
    if(m_State->ViewType==PanelViewType::ViewShort && columns_rest) { columns_width[2]++;  columns_rest--; }
    if(columns_rest) { columns_width[1]++;  columns_rest--; }
    
    int full_fn_column_width = m_SymbWidth - 23; if(full_fn_column_width < 0) full_fn_column_width = 0;
    int full_columns_width[] = {full_fn_column_width, 6, 8, 5};
    int full_column_fr_pos[] = {full_columns_width[0],
        full_columns_width[0] + full_columns_width[1] + 1,
        full_columns_width[0] + full_columns_width[1] + full_columns_width[2] + 2};
    
    auto &raw_entries = m_State->Data->DirectoryEntries();
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    UniChar buff[256];
    int path_name_start_pos = 0, path_name_end_pos = 0;
    int selected_bytes_start_pos = 0, selected_bytes_end_pos = 0;
    int bytes_in_dir_start_pos = 0, bytes_in_dir_end_pos = 0;
    int volume_info_start_pos = 0, volume_info_end_pos = 0;
    auto fontcache = m_FontCache.get();
    
    oms::Context omsc(context, fontcache);
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw file names
    omsc.SetupForText();
    for(int n = 0, i = m_State->ItemsDisplayOffset;
        n < max_files_to_show && i < sorted_entries.size();
        ++n, ++i)
    {
        const auto& current = raw_entries[ sorted_entries[i] ];
        
        oms::StringBuf<MAXPATHLEN> fn;
        fn.FromUTF8(current.Name(), current.NameLen());
        
        int CN = n / entries_in_column;
        int Y = (n % entries_in_column + 1);
        int X = 1;
        for(int i = 0; i < CN; ++i) X += columns_width[i];
        
        bool focused = (i == m_State->CursorPos) && View().active;
        auto text_color = GetDirectoryEntryTextColor(current, focused);
        
        if(m_State->ViewType != PanelViewType::ViewFull)
        {
            if(focused)
                omsc.DrawBackground(m_CursorBackgroundColor, X, Y, columns_width[CN] - 1);
        
            omsc.DrawString(fn.Chars(), 0, fn.MaxForSpaceLeft(columns_width[CN] - 1), X, Y, text_color);
        
            if(m_State->ViewType==PanelViewType::ViewWide)
            { // draw entry size on right side, only for this mode
                UniChar size_info[6];
                FormHumanReadableSizeReprentationForDirEnt6(current, size_info);
            
                if(focused)
                    omsc.DrawBackground(m_CursorBackgroundColor, columns_width[0]+1, Y, 6);
            
                omsc.DrawString(size_info, 0, 6, columns_width[0]+1, Y, text_color);
            }
        }
        else
        {
            UniChar size_info[6], date_info[8], time_info[5];;
            FormHumanReadableSizeReprentationForDirEnt6(current, size_info);
            FormHumanReadableDateRepresentation8(current.MTime(), date_info);
            FormHumanReadableTimeRepresentation5(current.MTime(), time_info);
            
            if(focused)
            {
                if(full_columns_width[0] > 0)
                    omsc.DrawBackground(m_CursorBackgroundColor, X, Y, full_columns_width[0] - 1);
                omsc.DrawBackground(m_CursorBackgroundColor, 1 + full_column_fr_pos[0], Y, 6);
                omsc.DrawBackground(m_CursorBackgroundColor, 1 + full_column_fr_pos[1], Y, 8);
                omsc.DrawBackground(m_CursorBackgroundColor, 1 + full_column_fr_pos[2], Y, 5);
            }
            
            if(full_columns_width[0] > 0)
                omsc.DrawString(fn.Chars(), 0, fn.MaxForSpaceLeft(full_columns_width[0] - 1), X, Y, text_color);
            omsc.DrawString(size_info, 0, 6, 1 + full_column_fr_pos[0], Y, text_color);
            omsc.DrawString(date_info, 0, 8, 1 + full_column_fr_pos[1], Y, text_color);
            omsc.DrawString(time_info, 0, 5, 1 + full_column_fr_pos[2], Y, text_color);
        }
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw header and footer data
    {
        const VFSListingItem *current_entry = 0;
        if(m_State->CursorPos >= 0) current_entry = &raw_entries[sorted_entries[m_State->CursorPos]];
        UniChar time_info[14], size_info[6], sort_mode[1];
        size_t buf_size = 0;
        FormHumanReadableSortModeReprentation1(m_State->Data->SortMode().sort, sort_mode);
        if(current_entry)
        {
            FormHumanReadableTimeRepresentation14(current_entry->MTime(), time_info);
            FormHumanReadableSizeReprentationForDirEnt6(*current_entry, size_info);
            ComposeFooterFileNameForEntry(*current_entry, buff, buf_size);
        }
        
        // draw sorting mode in left-upper corner
        oms::DrawSingleUniCharXY(sort_mode[0], 1, 0, context, fontcache, m_SelectedColor[0]);
        
        if(m_SymbWidth > 14)
        {   // need to draw a path name
            string pathutf8 = m_State->Data->VerboseDirectoryFullPath();

            oms::StringBuf<MAXPATHLEN*8> path;
            path.FromUTF8(pathutf8);
            path.TrimEllipsisLeft(m_SymbWidth - 7);
            
            int symbs = path.Space() + 2;
            path_name_start_pos = (m_SymbWidth-symbs) / 2;
            path_name_end_pos = path_name_start_pos + symbs;
            
            if(View().active)
                omsc.DrawBackground(m_CursorBackgroundColor, path_name_start_pos, 0, symbs);
                
            omsc.DrawString(path.Chars(), 0, path.Size(), path_name_start_pos+1, 0, m_RegularFileColor[View().active ? 1 : 0]);
        }
        
        // entry footer info
        if(current_entry && m_State->ViewType != PanelViewType::ViewFull)
        {
            if(m_SymbWidth > 2 + 14 + 6)
            {   // draw current entry time info, size info and maybe filename
                int Y = m_EntryFooterVPos;
                omsc.DrawString(time_info, 0, 14, m_SymbWidth - 15, Y, m_RegularFileColor[0]);
                omsc.DrawString(size_info, 0, 6, m_SymbWidth - 15 - 7, Y, m_RegularFileColor[0]);
                
                int symbs_for_name = m_SymbWidth - 2 - 14 - 6 - 2;
                if(symbs_for_name > 0)
                {
                    int symbs = oms::CalculateUniCharsAmountForSymbolsFromRight(buff, buf_size, symbs_for_name);
                    omsc.DrawString(buff, buf_size-symbs, symbs, 1, Y, m_RegularFileColor[0]);
                }
            }
            else if(m_SymbWidth >= 2 + 6)
            {   // draw current entry size info and maybe time info
                int Y = m_EntryFooterVPos;
                omsc.DrawString(size_info, 0, 6, 1, Y, m_RegularFileColor[0]);
                int symbs_for_name = m_SymbWidth - 2 - 6 - 1;
                if(symbs_for_name > 0)
                {
                    int symbs = oms::CalculateUniCharsAmountForSymbolsFromLeft(time_info, 14, symbs_for_name);
                    omsc.DrawString(time_info, 0, symbs, 8, Y, m_RegularFileColor[0]);
                }
            }
        }
        else if(current_entry)
        {
            int unics = oms::CalculateUniCharsAmountForSymbolsFromRight(buff, buf_size, m_SymbWidth-2);
            omsc.DrawString(buff, buf_size-unics, unics, 1, m_EntryFooterVPos, m_RegularFileColor[0]);
        }
        
        if(m_State->Data->Stats().selected_entries_amount != 0 && m_SymbWidth > 14)
        { // process selection if any
            UniChar selectionbuf[MAXPATHLEN];
            size_t sz;
            FormHumanReadableBytesAndFiles128(m_State->Data->Stats().bytes_in_selected_entries, m_State->Data->Stats().selected_entries_amount, selectionbuf, sz, true);
            oms::StringBuf<MAXPATHLEN> str;
            str.FromUniChars(selectionbuf, sz);
            str.TrimEllipsisLeft(m_SymbWidth - 2);
            
            int symbs = str.Space();
            selected_bytes_start_pos = (m_SymbWidth-symbs) / 2;
            selected_bytes_end_pos   = selected_bytes_start_pos + symbs;
            omsc.DrawBackground(m_CursorBackgroundColor, selected_bytes_start_pos, m_SelectionVPos, symbs);
            omsc.DrawString(str.Chars(), 0, str.Size(), selected_bytes_start_pos, m_SelectionVPos, m_SelectedColor[0]);
        }
        
        if(m_SymbWidth > 14)
        { // process bytes in directory
            UniChar bytes[128];
            size_t sz;
            FormHumanReadableBytesAndFiles128(m_State->Data->Stats().bytes_in_raw_reg_files, (int)m_State->Data->Stats().raw_reg_files_amount, bytes, sz, true);
            oms::StringBuf<MAXPATHLEN> str;
            str.FromUniChars(bytes, sz);
            str.TrimEllipsisLeft(m_SymbWidth - 2);
            
            int symbs = str.Space();
            bytes_in_dir_start_pos = (m_SymbWidth-symbs) / 2;
            bytes_in_dir_end_pos   = bytes_in_dir_start_pos + symbs;
            omsc.DrawString(str.Chars(), 0, str.Size(), bytes_in_dir_start_pos, m_BytesInDirectoryVPos, m_RegularFileColor[0]);
        }
        
        if(m_DrawVolumeInfo && m_SymbWidth > 14)
        {
            char bytes[128], buf[1024];
            UpdateStatFS();
            FormReadableBytes(StatFS().avail_bytes, bytes);
            sprintf(buf, " %s: %s bytes available ", StatFS().volume_name.c_str(), bytes);
            oms::StringBuf<1024> str;
            str.FromUTF8(buf, strlen(buf));
            str.TrimEllipsisLeft(m_SymbWidth - 2);
            
            int symbs = str.Space();
            volume_info_start_pos = (m_SymbWidth-symbs) / 2;
            volume_info_end_pos   = volume_info_start_pos + symbs;
            omsc.DrawString(str.Chars(), 0, str.Size(), volume_info_start_pos, m_SymbHeight-1, m_RegularFileColor[0]);
        }
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw frames
    omsc.SetupForASCIIArt();
    omsc.SetFillColor(m_RegularFileColor[0]);
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
        if(m_State->ViewType != PanelViewType::ViewFull)
            b.put(u'│', columns_width[0], i);
        if(m_State->ViewType == PanelViewType::ViewShort)
            b.put(u'│', columns_width[0]+columns_width[1], i);
        else if(m_State->ViewType == PanelViewType::ViewFull) {
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
        if(m_State->ViewType != PanelViewType::ViewFull &&
           ((i == columns_width[0]) || (i == columns_width[0] + columns_width[1])))
            is_col = true;
        else if(m_State->ViewType == PanelViewType::ViewFull &&
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
    return m_SymbHeight;
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
    tv.maxSize = NSMakeSize(FLT_MAX, rc.size.height);
    tv.textContainerInset = NSMakeSize(0, 0);
    tv.textContainer.lineFragmentPadding = line_padding;
}
