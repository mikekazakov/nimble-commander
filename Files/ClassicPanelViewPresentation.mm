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

// _out will be _not_ null-terminated, just a raw buffer
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

static void FormHumanReadableBytesAndFiles128(unsigned long _sz, int _total_files, UniChar _out[128], size_t &_symbs, bool _space_prefix_and_postfix)
{
    // TODO: localization support
    char buf[128];
    const char *postfix = _total_files > 1 ? "files" : "file";
    const char *space = _space_prefix_and_postfix ? " " : "";
#define __1000_1(a) ( (a) % 1000lu )
#define __1000_2(a) __1000_1( (a)/1000lu )
#define __1000_3(a) __1000_1( (a)/1000000lu )
#define __1000_4(a) __1000_1( (a)/1000000000lu )
#define __1000_5(a) __1000_1( (a)/1000000000000lu )
    if(_sz < 1000lu)
        sprintf(buf, "%s%lu bytes in %d %s%s", space, _sz, _total_files, postfix, space);
    else if(_sz < 1000lu * 1000lu)
        sprintf(buf, "%s%lu %03lu bytes in %d %s%s", space, __1000_2(_sz), __1000_1(_sz), _total_files, postfix, space);
    else if(_sz < 1000lu * 1000lu * 1000lu)
        sprintf(buf, "%s%lu %03lu %03lu bytes in %d %s%s", space, __1000_3(_sz), __1000_2(_sz), __1000_1(_sz), _total_files, postfix, space);
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu)
        sprintf(buf, "%s%lu %03lu %03lu %03lu bytes in %d %s%s", space, __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz), _total_files, postfix, space);
    else if(_sz < 1000lu * 1000lu * 1000lu * 1000lu * 1000lu)
        sprintf(buf, "%s%lu %03lu %03lu %03lu %03lu bytes in %d %s%s", space, __1000_5(_sz), __1000_4(_sz), __1000_3(_sz), __1000_2(_sz), __1000_1(_sz), _total_files, postfix, space);
#undef __1000_1
#undef __1000_2
#undef __1000_3
#undef __1000_4
#undef __1000_5
    
    _symbs = strlen(buf);
    for(int i = 0; i < _symbs; ++i) _out[i] = buf[i];
}

static void ComposeFooterFileNameForEntry(const VFSListingItem &_dirent, UniChar _buff[256], size_t &_sz)
{   // output is a direct filename or symlink path in ->filename form
    if(!_dirent.IsSymlink())
    {
        InterpretUTF8BufferAsUniChar( (unsigned char*) _dirent.Name(), _dirent.NameLen(), _buff, &_sz, 0xFFFD);
    }
    else
    {
        if(_dirent.Symlink() != 0)
        {
            _buff[0]='-';
            _buff[1]='>';
            InterpretUTF8BufferAsUniChar( (unsigned char*)_dirent.Symlink(), strlen(_dirent.Symlink()), _buff+2, &_sz, 0xFFFD);
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
:   m_SymbWidth(0),
    m_SymbHeight(0),
    m_FontCache(0)
{
    BuildGeometry();
    BuildAppearance();

    m_GeometryObserver = [[ObjcToCppObservingBridge alloc] initWithHandler:&OnGeometryChanged object:this];
    [m_GeometryObserver observeChangesInObject:[NSUserDefaults standardUserDefaults]
                                     forKeyPath:@"FilePanelsClassicFont"
                                         options:0
                                         context:0];
    
    m_AppearanceObserver = [[ObjcToCppObservingBridge alloc] initWithHandler:&OnAppearanceChanged object:this];
    [m_AppearanceObserver observeChangesInObject:[NSUserDefaults standardUserDefaults]
                                     forKeyPaths:[NSArray arrayWithObjects:@"FilePanelsClassicBackgroundColor",
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
                                                  @"FilePanelsClassicFocusedOtherColor", nil]
                                         options:0
                                         context:0];
}

ClassicPanelViewPresentation::~ClassicPanelViewPresentation()
{
    FontCache::ReleaseCache(m_FontCache);
}

void ClassicPanelViewPresentation::BuildGeometry()
{
    CTFontRef font = (CTFontRef)CFBridgingRetain([[NSUserDefaults standardUserDefaults] fontForKey:@"FilePanelsClassicFont"]);
    if(!font) font = CTFontCreateWithName( (CFStringRef) @"Menlo Regular", 15, 0);
    
    if(m_FontCache) FontCache::ReleaseCache(m_FontCache);
    m_FontCache = FontCache::FontCacheFromFont(font);
    CFRelease(font);
    
}

void ClassicPanelViewPresentation::BuildAppearance()
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

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

void ClassicPanelViewPresentation::OnAppearanceChanged(void *_obj, NSString *_key_path, id _objc_object, NSDictionary *_changed, void *_context)
{
    ClassicPanelViewPresentation *_this = (ClassicPanelViewPresentation *)_obj;
    _this->BuildAppearance();
    _this->SetViewNeedsDisplay();
}

void ClassicPanelViewPresentation::OnGeometryChanged(void *_obj, NSString *_key_path, id _objc_object, NSDictionary *_changed, void *_context)
{
    ClassicPanelViewPresentation *_this = (ClassicPanelViewPresentation *)_obj;
    _this->BuildGeometry();
    _this->m_SymbHeight = _this->m_FrameSize.height / _this->m_FontCache->Height();
    _this->m_SymbWidth = _this->m_FrameSize.width / _this->m_FontCache->Width();
    _this->EnsureCursorIsVisible();
    _this->SetViewNeedsDisplay();
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
    
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    
    // clear background
    m_BackgroundColor.Set(context);
    
    CGContextFillRect(context, NSRectToCGRect(_dirty_rect));
    
    PanelViewType type = m_State->ViewType;
    if (type == PanelViewType::ViewFull)
        DrawWithFullView(context);
    else
    {
        assert(type == PanelViewType::ViewShort
               || type == PanelViewType::ViewMedium
               || type == PanelViewType::ViewWide);
        
        DrawWithShortMediumWideView(context);
    }
}

void ClassicPanelViewPresentation::OnFrameChanged(NSRect _frame)
{
    m_FrameSize = _frame.size;
    m_SymbHeight = m_FrameSize.height / m_FontCache->Height();
    m_SymbWidth = m_FrameSize.width / m_FontCache->Width();
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
    if (file_number >= visible_files) file_number = visible_files - 1;
    
    return m_State->ItemsDisplayOffset + file_number;
}

int ClassicPanelViewPresentation::GetNumberOfItemColumns()
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

int ClassicPanelViewPresentation::GetMaxItemsPerColumn()
{
    if(m_State->ViewType == PanelViewType::ViewShort)
        return m_SymbHeight - 4;
    else if(m_State->ViewType == PanelViewType::ViewMedium)
        return m_SymbHeight - 4;
    else if(m_State->ViewType == PanelViewType::ViewFull)
        return m_SymbHeight - 4;
    else if(m_State->ViewType == PanelViewType::ViewWide)
        return m_SymbHeight - 4;
    else
        assert(0);
    return 1;
}

int ClassicPanelViewPresentation::Granularity()
{
    return m_FontCache->Width();
}

void ClassicPanelViewPresentation::DrawWithShortMediumWideView(CGContextRef context)
{
    // layout preparation
    const int columns_max = 3;
    const int columns = GetNumberOfItemColumns();
    int entries_in_column = GetMaxItemsPerColumn();
    int max_files_to_show = entries_in_column * columns;
    int column_width = (m_SymbWidth - 1) / columns;
    if(m_State->ViewType==PanelViewType::ViewWide) column_width = m_SymbWidth - 8;
    int columns_rest = m_SymbWidth - 1 - column_width*columns;
    int columns_width[columns_max] = {column_width, column_width, column_width};
    if(m_State->ViewType==PanelViewType::ViewShort && columns_rest) { columns_width[2]++;  columns_rest--; }
    if(columns_rest) { columns_width[1]++;  columns_rest--; }
    
    auto &raw_entries = m_State->Data->DirectoryEntries();
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    UniChar buff[256];
    int symbs_for_path_name = 0, path_name_start_pos = 0, path_name_end_pos = 0;
    int symbs_for_selected_bytes = 0, selected_bytes_start_pos = 0, selected_bytes_end_pos = 0;
    int symbs_for_bytes_in_dir = 0, bytes_in_dir_start_pos = 0, bytes_in_dir_end_pos = 0;
    auto fontcache = m_FontCache;
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw file names
    {
        int n=0,X,Y;
        oms::SetParamsForUserReadableText(context, m_FontCache);
        for(auto i = sorted_entries.begin() + m_State->ItemsDisplayOffset; i < sorted_entries.end(); ++i, ++n)
        {
            if(n >= max_files_to_show) break; // draw only visible
            const auto& current = raw_entries[*i];
            
            size_t buf_size = 0;
            
            InterpretUTF8BufferAsUniChar( (const unsigned char*)current.Name(), current.NameLen(), buff, &buf_size, 0xFFFD);
            
            int CN = n / entries_in_column;
            if(CN == 0) X = 1;
            else if(CN == 1) X = columns_width[0] + 1;
            else X = columns_width[0] + columns_width[1] + 1;
            Y = (n % entries_in_column + 1);
            
            if((m_State->ItemsDisplayOffset + n != m_State->CursorPos) || !m_State->Active)
                oms::DrawStringXY(buff, 0, oms::CalculateUniCharsAmountForSymbolsFromLeft(buff, buf_size, columns_width[CN] - 1),
                                  X, Y, context, fontcache, GetDirectoryEntryTextColor(current, false));
            else // cursor
                oms::DrawStringWithBackgroundXY(buff, 0, oms::CalculateUniCharsAmountForSymbolsFromLeft(buff, buf_size, columns_width[CN] - 1),
                                                X, Y, context, fontcache, GetDirectoryEntryTextColor(current, true), columns_width[CN] - 1, m_CursorBackgroundColor);
            
            if(m_State->ViewType==PanelViewType::ViewWide)
            { // draw entry size on right side, only for this mode
                UniChar size_info[6];
                FormHumanReadableSizeReprentationForDirEnt6(current, size_info);
                
                if((m_State->ItemsDisplayOffset + n != m_State->CursorPos) || !m_State->Active)
                    oms::DrawStringXY(size_info, 0, 6, columns_width[0]+1, Y, context, fontcache, GetDirectoryEntryTextColor(current, false));
                else // cursor
                    oms::DrawStringWithBackgroundXY(size_info, 0, 6, columns_width[0]+1, Y, context, fontcache, GetDirectoryEntryTextColor(current, true), 6, m_CursorBackgroundColor);
            }
        }
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw header and footer data
    {
        const VFSListingItem *current_entry = 0;
        if(m_State->CursorPos >= 0) current_entry = &raw_entries[sorted_entries[m_State->CursorPos]];
        UniChar time_info[14], size_info[6], sort_mode[1];
        size_t buf_size = 0;
        FormHumanReadableSortModeReprentation1(m_State->Data->GetCustomSortMode().sort, sort_mode);
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
            char panelpath[MAXPATHLEN*8];
            UniChar panelpathuni[MAXPATHLEN];
            UniChar panelpathtrim[256]; // may crash here on weird cases
            size_t panelpathsz;
            m_State->Data->GetDirectoryFullHostsPathWithTrailingSlash(panelpath);
            InterpretUTF8BufferAsUniChar( (unsigned char*)panelpath, strlen(panelpath), panelpathuni, &panelpathsz, 0xFFFD);
            int chars_for_path_name = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(panelpathuni, panelpathsz, m_SymbWidth - 7, panelpathtrim);
            
            // add prefix and postfix - " "
            memmove(panelpathtrim+1, panelpathtrim, sizeof(UniChar)*chars_for_path_name);
            panelpathtrim[0] = ' ';
            panelpathtrim[chars_for_path_name+1] = ' ';
            chars_for_path_name += 2;
            symbs_for_path_name = oms::CalculateSymbolsSpaceForString(panelpathtrim, chars_for_path_name);
            path_name_start_pos = (m_SymbWidth-symbs_for_path_name) / 2;
            path_name_end_pos = (m_SymbWidth-symbs_for_path_name) / 2 + symbs_for_path_name;
            
            if(m_State->Active)
                oms::DrawStringWithBackgroundXY(panelpathtrim, 0, chars_for_path_name, path_name_start_pos, 0,
                                                context, fontcache, m_RegularFileColor[1], symbs_for_path_name, m_CursorBackgroundColor);
            else
                oms::DrawStringXY(panelpathtrim, 0, chars_for_path_name, path_name_start_pos, 0,
                                  context, fontcache, m_RegularFileColor[0]);
        }
        
        // footer info
        if(current_entry && m_SymbWidth > 2 + 14 + 6)
        {   // draw current entry time info, size info and maybe filename
            oms::DrawStringXY(time_info, 0, 14, m_SymbWidth - 15, m_SymbHeight - 2, context, fontcache, m_RegularFileColor[0]);
            oms::DrawStringXY(size_info, 0, 6, m_SymbWidth - 15 - 7, m_SymbHeight - 2, context, fontcache, m_RegularFileColor[0]);
            
            int symbs_for_name = m_SymbWidth - 2 - 14 - 6 - 2;
            if(symbs_for_name > 0)
            {
                int symbs = oms::CalculateUniCharsAmountForSymbolsFromRight(buff, buf_size, symbs_for_name);
                oms::DrawStringXY(buff, buf_size-symbs, symbs, 1, m_SymbHeight-2, context, fontcache, m_RegularFileColor[0]);
            }
        }
        else if(current_entry && m_SymbWidth >= 2 + 6)
        {   // draw current entry size info and time info
            oms::DrawStringXY(size_info, 0, 6, 1, m_SymbHeight - 2, context, fontcache, m_RegularFileColor[0]);
            int symbs_for_name = m_SymbWidth - 2 - 6 - 1;
            if(symbs_for_name > 0)
            {
                int symbs = oms::CalculateUniCharsAmountForSymbolsFromLeft(time_info, 14, symbs_for_name);
                oms::DrawStringXY(time_info, 0, symbs, 8, m_SymbHeight-2, context, fontcache, m_RegularFileColor[0]);
            }
        }
        
        if(m_State->Data->GetSelectedItemsCount() != 0 && m_SymbWidth > 12)
        { // process selection if any
            UniChar selectionbuf[128], selectionbuftrim[128];
            size_t sz;
            FormHumanReadableBytesAndFiles128(m_State->Data->GetSelectedItemsSizeBytes(), m_State->Data->GetSelectedItemsCount(), selectionbuf, sz, true);
            int unichars = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(selectionbuf, sz, m_SymbWidth - 2, selectionbuftrim);
            symbs_for_selected_bytes = oms::CalculateSymbolsSpaceForString(selectionbuftrim, unichars);
            selected_bytes_start_pos = (m_SymbWidth-symbs_for_selected_bytes) / 2;
            selected_bytes_end_pos   = selected_bytes_start_pos + symbs_for_selected_bytes;
            oms::DrawStringWithBackgroundXY(selectionbuftrim, 0, unichars,
                                            selected_bytes_start_pos, m_SymbHeight-3,
                                            context, fontcache, m_SelectedColor[0], symbs_for_selected_bytes, m_CursorBackgroundColor);
        }
        
        if(m_SymbWidth > 12)
        { // process bytes in directory
            UniChar bytes[128], bytestrim[128];
            size_t sz;
            FormHumanReadableBytesAndFiles128(m_State->Data->GetTotalBytesInDirectory(), (int)m_State->Data->GetTotalFilesInDirectory(), bytes, sz, true);
            int unichars = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(bytes, sz, m_SymbWidth - 2, bytestrim);
            symbs_for_bytes_in_dir = oms::CalculateSymbolsSpaceForString(bytestrim, unichars);
            bytes_in_dir_start_pos = (m_SymbWidth-symbs_for_bytes_in_dir) / 2;
            bytes_in_dir_end_pos   = bytes_in_dir_start_pos + symbs_for_bytes_in_dir;
            oms::DrawStringXY(bytestrim, 0, unichars,
                              bytes_in_dir_start_pos, m_SymbHeight-1,
                              context, fontcache, m_RegularFileColor[0]);
        }
        
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw frames
    oms::SetParamsForUserASCIIArt(context, m_FontCache);
    oms::SetFillColor(context, m_RegularFileColor[0]);
    oms::unichars_draw_batch b;
    
    for(int i = 1; i < m_SymbHeight - 1; ++i)
    {
        b.put(i != m_SymbHeight - 3 ? u'║' : u'╟', 0, i);
        b.put(i != m_SymbHeight - 3 ? u'║' : u'╢', m_SymbWidth-1, i);
    }
    b.put(u'╔', 0, 0);
    b.put(u'╚', 0, m_SymbHeight-1);
    b.put(u'╝', m_SymbWidth-1, m_SymbHeight-1);
    b.put(u'╗', m_SymbWidth-1, 0);
    if(columns_width[0] < path_name_start_pos || columns_width[0] >= path_name_end_pos)
        b.put(u'╤', columns_width[0], 0);
    if(columns_width[0]+columns_width[1] < path_name_start_pos || columns_width[0]+columns_width[1] >= path_name_end_pos)
        if(m_State->ViewType==PanelViewType::ViewShort)
            b.put(u'╤', columns_width[0]+columns_width[1], 0);
    for(int i = 1; i < m_SymbHeight - 3; ++i)
    {
        b.put(u'│', columns_width[0], i);
        if(m_State->ViewType==PanelViewType::ViewShort)
            b.put(u'│', columns_width[0]+columns_width[1], i);
    }
    for(int i = 1; i < m_SymbWidth - 1; ++i)
    {
        if( (i != columns_width[0]) && (i != columns_width[0] + columns_width[1]))
        {
            if( (i!=1) && (i < path_name_start_pos || i >= path_name_end_pos))
                b.put(u'═', i, 0);
            if(i < selected_bytes_start_pos || i >= selected_bytes_end_pos )
                b.put(u'─', i, m_SymbHeight-3);
        }
        else
        {
            if(i < selected_bytes_start_pos || i >= selected_bytes_end_pos )
                b.put(u'┴', i, m_SymbHeight-3);
        }
        if(i < bytes_in_dir_start_pos || i >= bytes_in_dir_end_pos)
            b.put(u'═', i, m_SymbHeight-1);
    }
    oms::DrawUniCharsXY(b, context, fontcache);
}

void ClassicPanelViewPresentation::DrawWithFullView(CGContextRef context)
{
    const int columns_max = 4;
    int fn_column_width = m_SymbWidth - 23; if(fn_column_width < 0) fn_column_width = 0;
    int entries_to_show = GetMaxItemsPerColumn();
    int columns_width[columns_max] = {fn_column_width, 6, 8, 5};
    int column_fr_pos[columns_max-1] = {columns_width[0],
        columns_width[0] + columns_width[1] + 1,
        columns_width[0] + columns_width[1] + columns_width[2] + 2};
    int symbs_for_bytes_in_dir = 0, bytes_in_dir_start_pos = 0, bytes_in_dir_end_pos = 0;
    int symbs_for_path_name = 0, path_name_start_pos = 0, path_name_end_pos = 0;
    int symbs_for_selected_bytes = 0, selected_bytes_start_pos = 0, selected_bytes_end_pos = 0;
    auto &raw_entries = m_State->Data->DirectoryEntries();
    auto &sorted_entries = m_State->Data->SortedDirectoryEntries();
    auto fontcache = m_FontCache;
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw file names
    {
        UniChar file_name[256], size_info[6], date_info[8], time_info[5];;
        size_t fn_size = 0;
        int n=0;
        oms::SetParamsForUserReadableText(context, m_FontCache);
        for(auto i = sorted_entries.begin() + m_State->ItemsDisplayOffset; i < sorted_entries.end(); ++i, ++n)
        {
            if(n >= entries_to_show) break; // draw only visible
            const auto& current = raw_entries[*i];
            
            // TODO: need to render extention apart from other filename. (need ?)
            InterpretUTF8BufferAsUniChar( (const unsigned char*)current.Name(), current.NameLen(), file_name, &fn_size, 0xFFFD);
            FormHumanReadableSizeReprentationForDirEnt6(current, size_info);
            FormHumanReadableDateRepresentation8(current.MTime(), date_info);
            FormHumanReadableTimeRepresentation5(current.MTime(), time_info);
            
            if((m_State->ItemsDisplayOffset + n != m_State->CursorPos) || !m_State->Active)
            {
                auto &textcolor = GetDirectoryEntryTextColor(current, false);
                oms::DrawStringXY(file_name, 0, oms::CalculateUniCharsAmountForSymbolsFromLeft(file_name, fn_size, columns_width[0] - 1),
                                  1, n+1, context, fontcache, textcolor);
                
                oms::DrawStringXY(size_info, 0, 6, 1 + column_fr_pos[0], n+1, context, fontcache, textcolor);
                oms::DrawStringXY(date_info, 0, 8, 1 + column_fr_pos[1], n+1, context, fontcache, textcolor);
                oms::DrawStringXY(time_info, 0, 5, 1 + column_fr_pos[2], n+1, context, fontcache, textcolor);
            }
            else // cursor
            {
                auto &textcolor = GetDirectoryEntryTextColor(current, true);
                auto &textbkcolor = m_CursorBackgroundColor;
                oms::DrawStringWithBackgroundXY(file_name, 0, oms::CalculateUniCharsAmountForSymbolsFromLeft(file_name, fn_size, columns_width[0] - 1),
                                                1, n+1, context, fontcache, textcolor, columns_width[0] - 1, textbkcolor);
                oms::DrawStringWithBackgroundXY(size_info, 0, 6, 1 + column_fr_pos[0], n+1,
                                                context, fontcache, textcolor, 6, textbkcolor);
                oms::DrawStringWithBackgroundXY(date_info, 0, 8, 1 + column_fr_pos[1], n+1,
                                                context, fontcache, textcolor, 8, textbkcolor);
                oms::DrawStringWithBackgroundXY(time_info, 0, 5, 1 + column_fr_pos[2], n+1,
                                                context, fontcache, textcolor, 5, textbkcolor);
            }
        }
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw directory path
    if(m_SymbWidth > 14)
    {   // need to draw a path name
        char panelpath[MAXPATHLEN*8];
        UniChar panelpathuni[MAXPATHLEN];
        UniChar panelpathtrim[256]; // may crash here on weird cases
        size_t panelpathsz;
        m_State->Data->GetDirectoryFullHostsPathWithTrailingSlash(panelpath);
        InterpretUTF8BufferAsUniChar( (unsigned char*)panelpath, strlen(panelpath), panelpathuni, &panelpathsz, 0xFFFD);
        int chars_for_path_name = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(panelpathuni, panelpathsz, m_SymbWidth - 7, panelpathtrim);
        
        // add prefix and postfix - " "
        memmove(panelpathtrim+1, panelpathtrim, sizeof(UniChar)*chars_for_path_name);
        panelpathtrim[0] = ' ';
        panelpathtrim[chars_for_path_name+1] = ' ';
        chars_for_path_name += 2;
        symbs_for_path_name = oms::CalculateSymbolsSpaceForString(panelpathtrim, chars_for_path_name);
        path_name_start_pos = (m_SymbWidth-symbs_for_path_name) / 2;
        path_name_end_pos = (m_SymbWidth-symbs_for_path_name) / 2 + symbs_for_path_name;
        
        if(m_State->Active)
            oms::DrawStringWithBackgroundXY(panelpathtrim, 0, chars_for_path_name, path_name_start_pos, 0,
                                            context, fontcache, m_RegularFileColor[1], symbs_for_path_name, m_CursorBackgroundColor);
        else
            oms::DrawStringXY(panelpathtrim, 0, chars_for_path_name, path_name_start_pos, 0,
                              context, fontcache, m_RegularFileColor[0]);
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw sorting mode
    {
        UniChar sort_mode[1];
        FormHumanReadableSortModeReprentation1(m_State->Data->GetCustomSortMode().sort, sort_mode);
        oms::DrawSingleUniCharXY(sort_mode[0], 1, 0, context, fontcache, m_SelectedColor[0]);
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw bytes in directory
    if(m_SymbWidth > 12)
    { // process bytes in directory
        UniChar bytes[128], bytestrim[128];
        size_t sz;
        FormHumanReadableBytesAndFiles128(m_State->Data->GetTotalBytesInDirectory(), (int)m_State->Data->GetTotalFilesInDirectory(), bytes, sz, true);
        int unichars = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(bytes, sz, m_SymbWidth - 2, bytestrim);
        symbs_for_bytes_in_dir = oms::CalculateSymbolsSpaceForString(bytestrim, unichars);
        bytes_in_dir_start_pos = (m_SymbWidth-symbs_for_bytes_in_dir) / 2;
        bytes_in_dir_end_pos   = bytes_in_dir_start_pos + symbs_for_bytes_in_dir;
        oms::DrawStringXY(bytestrim, 0, unichars, bytes_in_dir_start_pos, m_SymbHeight-1, context, fontcache, m_RegularFileColor[0]);
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw selection if any
    if(m_State->Data->GetSelectedItemsCount() != 0 && m_SymbWidth > 12)
    {
        UniChar selectionbuf[128], selectionbuftrim[128];
        size_t sz;
        FormHumanReadableBytesAndFiles128(m_State->Data->GetSelectedItemsSizeBytes(), m_State->Data->GetSelectedItemsCount(), selectionbuf, sz, true);
        int unichars = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(selectionbuf, sz, m_SymbWidth - 2, selectionbuftrim);
        symbs_for_selected_bytes = oms::CalculateSymbolsSpaceForString(selectionbuftrim, unichars);
        selected_bytes_start_pos = (m_SymbWidth-symbs_for_selected_bytes) / 2;
        selected_bytes_end_pos   = selected_bytes_start_pos + symbs_for_selected_bytes;
        oms::DrawStringWithBackgroundXY(selectionbuftrim, 0, unichars,
                                        selected_bytes_start_pos, m_SymbHeight-3,
                                        context, fontcache, m_SelectedColor[0], symbs_for_selected_bytes, m_CursorBackgroundColor);
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw footer data
    if(m_State->CursorPos >= 0 )
    {
        UniChar buff[256];
        size_t buf_size;
        
        const auto &current_entry = raw_entries[sorted_entries[m_State->CursorPos]];
        ComposeFooterFileNameForEntry(current_entry, buff, buf_size);
        int symbs = oms::CalculateUniCharsAmountForSymbolsFromRight(buff, buf_size, m_SymbWidth-2);
        oms::DrawStringXY(buff, buf_size-symbs, symbs, 1, m_SymbHeight-2, context, fontcache, m_RegularFileColor[0]);
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw frames
    oms::SetParamsForUserASCIIArt(context, m_FontCache);
    oms::SetFillColor(context, m_RegularFileColor[0]);
    oms::unichars_draw_batch b;
    
    b.put(u'╔', 0, 0);
    b.put(u'╚', 0, m_SymbHeight-1);
    b.put(u'╝', m_SymbWidth-1, m_SymbHeight-1);
    b.put(u'╗', m_SymbWidth-1, 0);
    for(int i = 1; i < m_SymbHeight - 3; ++i)
    {
        b.put(u'│', column_fr_pos[0], i);
        b.put(u'│', column_fr_pos[1], i);
        b.put(u'│', column_fr_pos[2], i);
    }
    
    for(int i = 1; i < m_SymbHeight - 1; ++i)
    {
        b.put(i != m_SymbHeight - 3 ? u'║' : u'╟', 0, i);
        b.put(i != m_SymbHeight - 3 ? u'║' : u'╢', m_SymbWidth-1, i);
    }
    
    for(int i = 1; i < m_SymbWidth - 1; ++i)
    {
        if(i != column_fr_pos[0] && i != column_fr_pos[1] && i != column_fr_pos[2])
        {
            if( (i!=1) && (i < path_name_start_pos || i >= path_name_end_pos))
                b.put(u'═', i, 0);
            if(i < selected_bytes_start_pos || i >= selected_bytes_end_pos )
                b.put(u'─', i, m_SymbHeight-3);
        }
        else
        {
            if( (i!=1) && (i < path_name_start_pos || i >= path_name_end_pos))
                b.put(u'╤', i, 0);
            if(i < selected_bytes_start_pos || i >= selected_bytes_end_pos )
                b.put(u'┴', i, m_SymbHeight-3);
        }
        if(i < bytes_in_dir_start_pos || i >= bytes_in_dir_end_pos)
            b.put(u'═', i, m_SymbHeight-1);
    }
    
    oms::DrawUniCharsXY(b, context, fontcache);
}
