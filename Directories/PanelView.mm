//
//  PanelView.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.02.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelView.h"
#include "PanelData.h"
#include "Encodings.h"
#include "FontCache.h"

#include <stack>
#include <stdio.h>
#include <stdlib.h>

#include "OrthodoxMonospace.h"

#import "QuickPreview.h"
#import "PanelController.h"


#define FONTSIZE 15.0f
#define FONTWIDTH 9
#define FONTHEIGHT 20

#define ISUNICODECOMBININGCHARACTER(a) (\
    ((a) >= 0x0300 && (a) <= 0x036F) || \
    ((a) >= 0x1DC0 && (a) <= 0x1DFF) || \
    ((a) >= 0x20D0 && (a) <= 0x20FF) || \
    ((a) >= 0xFE20 && (a) <= 0xFE2F) )

static const DoubleColor g_RegFileColor(0, 1, 1, 1);
static const DoubleColor g_DirFileColor(1, 1, 1, 1);
static const DoubleColor g_HidFileColor(0, 0.5, 0.5, 1);
static const DoubleColor g_UnkFileColor(1, 0, 0, 1);

static const DoubleColor g_FocRegFileColor(0, 0, 0, 1);
static const DoubleColor g_FocHidFileColor(0.5, 0.5, 0.5, 1);
static const DoubleColor g_FocDirFileColor(1, 1, 1, 1);

static const DoubleColor g_SelFileColor(1, 1, 0, 1);

static const DoubleColor g_FocFileBkColor(0, 0.5, 0.5, 1);
static const DoubleColor g_HeaderInfoColor(1, 1, 0, 1);

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

static const DoubleColor& GetDirectoryEntryTextColor(const DirectoryEntryInformation &_dirent, bool _is_focused)
{
    // TODO: consider using special coloring for symlink to distinguish them

    if(_dirent.cf_isselected())
        return g_SelFileColor;
    
    if(_is_focused)
    {   // focused case
        if(_dirent.ishidden()) return g_FocHidFileColor;
        else if(_dirent.isreg() || _dirent.isdotdot()) return g_FocRegFileColor;
        else if(_dirent.isdir()) return g_FocDirFileColor;
    }
    else
    {   // regular case
        if(_dirent.ishidden()) return g_HidFileColor;
        else if(_dirent.isreg() ||  _dirent.isdotdot()) return g_RegFileColor;
        else if(_dirent.isdir()) return g_DirFileColor;
    }
 
    return g_UnkFileColor;
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

static int ColumnsNumberForViewType(PanelViewType _type)
{
    switch(_type)
    {
        case PanelViewType::ViewShort: return 3;
        case PanelViewType::ViewMedium: return 2;
        case PanelViewType::ViewWide: return 1;
        case PanelViewType::ViewFull: return 1;
        default: assert(0);
    }
}

////////////////////////////////////////////////////////////////////////////////

struct CursorSelectionState
{
    enum Type
    {
        No,
        Selection,
        Unselection
    };
};

@implementation PanelView
{
    PanelController *m_Controller;
    PanelData       *m_Data;
    int             m_SymbWidth;
    int             m_SymbHeight;
    int             m_FilesDisplayOffset; // number of a first file which appears on the panel view, on the top
    std::stack<int> m_DisplayOffsetStack;
    int             m_CursorPosition; // -1 means no real cursor position
    PanelViewType   m_CurrentViewType;
    bool            m_IsActive;
    
    CTFontRef       m_FontCT;
    CGFontRef       m_FontCG;
    unsigned long   m_KeysModifiersFlags;
    CursorSelectionState::Type m_CursorSelectionType;
}

- (BOOL)isFlipped
{
    return YES;
}

- (BOOL)isOpaque
{
    return YES;
}

- (void) Activate
{
    if(m_IsActive == false)
    {
        m_IsActive = true;
        [self setNeedsDisplay:true];
    }
}

- (void) Disactivate
{
    if(m_IsActive == true)
    {
        m_IsActive = false;
        [self setNeedsDisplay:true];
    }
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        m_Data = 0;
        m_FontCT = CTFontCreateWithName( (CFStringRef) @"Menlo Regular", FONTSIZE, 0);
        m_FontCG = CTFontCopyGraphicsFont(m_FontCT, 0);
//        m_FontCache = new FontCache(m_FontCT);
        m_FilesDisplayOffset = 0;
        m_CursorPosition = -1;
        m_CurrentViewType = PanelViewType::ViewMedium;
        m_IsActive = false;
        m_KeysModifiersFlags = 0;
        m_CursorSelectionType = CursorSelectionState::No;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(frameDidChange)
                                                     name:NSViewFrameDidChangeNotification
                                                   object:self];
        [self frameDidChange];
    }
    
    return self;
}

-(void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (int)CalcMaxShownFilesForView:(PanelViewType) _view
{
    if(_view == PanelViewType::ViewShort)
        return [self CalcMaxShownFilesPerPanelForView:_view] * 3;
    if(_view == PanelViewType::ViewMedium)
        return [self CalcMaxShownFilesPerPanelForView:_view] * 2;
    if(_view == PanelViewType::ViewFull)
        return [self CalcMaxShownFilesPerPanelForView:_view];
    if(_view == PanelViewType::ViewWide)
        return [self CalcMaxShownFilesPerPanelForView:_view];

    assert(0);
    return 1;
}

- (int)CalcMaxShownFilesPerPanelForView:(PanelViewType) _view
{
    if(_view == PanelViewType::ViewShort)
        return m_SymbHeight - 4;
    else if(_view == PanelViewType::ViewMedium)
        return m_SymbHeight - 4;
    else if(_view == PanelViewType::ViewFull)
        return m_SymbHeight - 4;
    else if(_view == PanelViewType::ViewWide)
        return m_SymbHeight - 4;
    else
        assert(0);
    return 1;
}

- (void)DrawWithShortMediumWideView:(CGContextRef) context
{
    // layout preparation
    const int columns_max = 3;
    const int columns = ColumnsNumberForViewType(m_CurrentViewType);
    int entries_in_column = [self CalcMaxShownFilesPerPanelForView:m_CurrentViewType];
    int max_files_to_show = entries_in_column * columns;
    int column_width = (m_SymbWidth - 1) / columns;
    if(m_CurrentViewType==PanelViewType::ViewWide) column_width = m_SymbWidth - 8;
    int columns_rest = m_SymbWidth - 1 - column_width*columns;
    int columns_width[columns_max] = {column_width, column_width, column_width};
    if(m_CurrentViewType==PanelViewType::ViewShort && columns_rest) { columns_width[2]++;  columns_rest--; }
    if(columns_rest) { columns_width[1]++;  columns_rest--; }

    auto &raw_entries = m_Data->DirectoryEntries();
    auto &sorted_entries = m_Data->SortedDirectoryEntries();
    UniChar buff[256];
    int symbs_for_path_name = 0, path_name_start_pos = 0, path_name_end_pos = 0;
    int symbs_for_selected_bytes = 0, selected_bytes_start_pos = 0, selected_bytes_end_pos = 0;
    int symbs_for_bytes_in_dir = 0, bytes_in_dir_start_pos = 0, bytes_in_dir_end_pos = 0;
    auto fontcache = FontCacheManager::Instance()->Get();
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw file names
    {
    int n=0,X,Y;
    oms::SetParamsForUserReadableText(context, m_FontCG, m_FontCT);
    for(auto i = sorted_entries.begin() + m_FilesDisplayOffset; i < sorted_entries.end(); ++i, ++n)
    {
        if(n >= max_files_to_show) break; // draw only visible
        const auto& current = raw_entries[*i];
        
        size_t buf_size = 0;
        
        InterpretUTF8BufferAsUniChar( current.name(), current.namelen, buff, &buf_size, 0xFFFD);
        
        int CN = n / entries_in_column;
        if(CN == 0) X = 1;
        else if(CN == 1) X = columns_width[0] + 1;
        else X = columns_width[0] + columns_width[1] + 1;
        Y = (n % entries_in_column + 1);
        
        if((m_FilesDisplayOffset + n != m_CursorPosition) || !m_IsActive)
            oms::DrawStringXY(buff, 0, oms::CalculateUniCharsAmountForSymbolsFromLeft(buff, buf_size, columns_width[CN] - 1),
                X, Y, context, fontcache, GetDirectoryEntryTextColor(current, false));
        else // cursor
            oms::DrawStringWithBackgroundXY(buff, 0, oms::CalculateUniCharsAmountForSymbolsFromLeft(buff, buf_size, columns_width[CN] - 1),
                X, Y, context, fontcache, GetDirectoryEntryTextColor(current, true), columns_width[CN] - 1, g_FocFileBkColor);
  
        if(m_CurrentViewType==PanelViewType::ViewWide)
        { // draw entry size on right side, only for this mode
            UniChar size_info[6];
            FormHumanReadableSizeReprentationForDirEnt6(&current, size_info);

            if((m_FilesDisplayOffset + n != m_CursorPosition) || !m_IsActive)
                oms::DrawStringXY(size_info, 0, 6, columns_width[0]+1, Y, context, fontcache, GetDirectoryEntryTextColor(current, false));
            else // cursor
                oms::DrawStringWithBackgroundXY(size_info, 0, 6, columns_width[0]+1, Y, context, fontcache, GetDirectoryEntryTextColor(current, true), 6, g_FocFileBkColor);
        }
    }
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw header and footer data
    {
    const DirectoryEntryInformation *current_entry = 0;
    if(m_CursorPosition >= 0) current_entry = &raw_entries[sorted_entries[m_CursorPosition]];
    UniChar time_info[14], size_info[6], sort_mode[1];
    size_t buf_size = 0;
    FormHumanReadableSortModeReprentation1(m_Data->GetCustomSortMode().sort, sort_mode);
    if(current_entry)
    {
    FormHumanReadableTimeRepresentation14(current_entry->mtime, time_info);
    FormHumanReadableSizeReprentationForDirEnt6(current_entry, size_info);
    ComposeFooterFileNameForEntry(*current_entry, buff, buf_size);
    }
    
    // draw sorting mode in left-upper corner
    oms::DrawSingleUniCharXY(sort_mode[0], 1, 0, context, fontcache, g_HeaderInfoColor);

    if(m_SymbWidth > 14)
    {   // need to draw a path name
        char panelpath[__DARWIN_MAXPATHLEN];
        UniChar panelpathuni[__DARWIN_MAXPATHLEN];
        UniChar panelpathtrim[256]; // may crash here on weird cases
        size_t panelpathsz;
        m_Data->GetDirectoryPathWithTrailingSlash(panelpath);
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
        
        if(m_IsActive)
            oms::DrawStringWithBackgroundXY(panelpathtrim, 0, chars_for_path_name, path_name_start_pos, 0,
                                        context, fontcache, g_FocRegFileColor, symbs_for_path_name, g_FocFileBkColor);
        else
            oms::DrawStringXY(panelpathtrim, 0, chars_for_path_name, path_name_start_pos, 0,
                                        context, fontcache, g_RegFileColor);
    }

    // footer info        
    if(current_entry && m_SymbWidth > 2 + 14 + 6)
    {   // draw current entry time info, size info and maybe filename
        oms::DrawStringXY(time_info, 0, 14, m_SymbWidth - 15, m_SymbHeight - 2, context, fontcache, g_RegFileColor);
        oms::DrawStringXY(size_info, 0, 6, m_SymbWidth - 15 - 7, m_SymbHeight - 2, context, fontcache, g_RegFileColor);
        
        int symbs_for_name = m_SymbWidth - 2 - 14 - 6 - 2;
        if(symbs_for_name > 0)
        {
            int symbs = oms::CalculateUniCharsAmountForSymbolsFromRight(buff, buf_size, symbs_for_name);
            oms::DrawStringXY(buff, buf_size-symbs, symbs, 1, m_SymbHeight-2, context, fontcache, g_RegFileColor);
        }
    }
    else if(current_entry && m_SymbWidth >= 2 + 6)
    {   // draw current entry size info and time info
        oms::DrawString(size_info, 0, 6, 1, m_SymbHeight - 2, context, fontcache, g_RegFileColor);
        int symbs_for_name = m_SymbWidth - 2 - 6 - 1;
        if(symbs_for_name > 0)
        {
            int symbs = oms::CalculateUniCharsAmountForSymbolsFromLeft(time_info, 14, symbs_for_name);
            oms::DrawStringXY(time_info, 0, symbs, 8, m_SymbHeight-2, context, fontcache, g_RegFileColor);
        }
    }
        
    if(m_Data->GetSelectedItemsCount() != 0 && m_SymbWidth > 12)
    { // process selection if any
        UniChar selectionbuf[128], selectionbuftrim[128];
        size_t sz;
        FormHumanReadableBytesAndFiles128(m_Data->GetSelectedItemsSizeBytes(), m_Data->GetSelectedItemsCount(), selectionbuf, sz, true);
        int unichars = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(selectionbuf, sz, m_SymbWidth - 2, selectionbuftrim);
        symbs_for_selected_bytes = oms::CalculateSymbolsSpaceForString(selectionbuftrim, unichars);
        selected_bytes_start_pos = (m_SymbWidth-symbs_for_selected_bytes) / 2;
        selected_bytes_end_pos   = selected_bytes_start_pos + symbs_for_selected_bytes;
        oms::DrawStringWithBackgroundXY(selectionbuftrim, 0, unichars,
                                 selected_bytes_start_pos, m_SymbHeight-3,
                                 context, fontcache, g_HeaderInfoColor, symbs_for_selected_bytes, g_FocFileBkColor);
    }

    if(m_SymbWidth > 12)
    { // process bytes in directory
        UniChar bytes[128], bytestrim[128];
        size_t sz;
        FormHumanReadableBytesAndFiles128(m_Data->GetTotalBytesInDirectory(), (int)m_Data->GetTotalFilesInDirectory(), bytes, sz, true);
        int unichars = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(bytes, sz, m_SymbWidth - 2, bytestrim);
        symbs_for_bytes_in_dir = oms::CalculateSymbolsSpaceForString(bytestrim, unichars);
        bytes_in_dir_start_pos = (m_SymbWidth-symbs_for_bytes_in_dir) / 2;
        bytes_in_dir_end_pos   = bytes_in_dir_start_pos + symbs_for_bytes_in_dir;
        oms::DrawStringXY(bytestrim, 0, unichars,
                                 bytes_in_dir_start_pos, m_SymbHeight-1,
                                 context, fontcache, g_RegFileColor);
    }

    }

    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw frames
    oms::SetParamsForUserASCIIArt(context, m_FontCG, m_FontCT);
    oms::SetFillColor(context, g_RegFileColor);
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
        if(m_CurrentViewType==PanelViewType::ViewShort)
            b.put(u'╤', columns_width[0]+columns_width[1], 0);
    for(int i = 1; i < m_SymbHeight - 3; ++i)
    {
        b.put(u'│', columns_width[0], i);
        if(m_CurrentViewType==PanelViewType::ViewShort)
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

- (void)DrawWithFullView:(CGContextRef) context
{
    const int columns_max = 4;
    int fn_column_width = m_SymbWidth - 23; if(fn_column_width < 0) fn_column_width = 0;
    int entries_to_show = [self CalcMaxShownFilesPerPanelForView:m_CurrentViewType];
    int columns_width[columns_max] = {fn_column_width, 6, 8, 5};
    int column_fr_pos[columns_max-1] = {columns_width[0],
                                        columns_width[0] + columns_width[1] + 1,
                                        columns_width[0] + columns_width[1] + columns_width[2] + 2};
    int symbs_for_bytes_in_dir = 0, bytes_in_dir_start_pos = 0, bytes_in_dir_end_pos = 0;
    int symbs_for_path_name = 0, path_name_start_pos = 0, path_name_end_pos = 0;
    int symbs_for_selected_bytes = 0, selected_bytes_start_pos = 0, selected_bytes_end_pos = 0;    
    auto &raw_entries = m_Data->DirectoryEntries();
    auto &sorted_entries = m_Data->SortedDirectoryEntries();
    auto fontcache = FontCacheManager::Instance()->Get();    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw file names
    {
        UniChar file_name[256], size_info[6], date_info[8], time_info[5];;
        size_t fn_size = 0;
        int n=0;
        oms::SetParamsForUserReadableText(context, m_FontCG, m_FontCT);
        for(auto i = sorted_entries.begin() + m_FilesDisplayOffset; i < sorted_entries.end(); ++i, ++n)
        {
            if(n >= entries_to_show) break; // draw only visible
            const auto& current = raw_entries[*i];

            // TODO: need to render extention apart from other filename. (need ?)
            InterpretUTF8BufferAsUniChar( current.name(), current.namelen, file_name, &fn_size, 0xFFFD);
            FormHumanReadableSizeReprentationForDirEnt6(&current, size_info);
            FormHumanReadableDateRepresentation8(current.mtime, date_info);
            FormHumanReadableTimeRepresentation5(current.mtime, time_info);

            if((m_FilesDisplayOffset + n != m_CursorPosition) || !m_IsActive)
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
                auto &textbkcolor = g_FocFileBkColor;
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
        char panelpath[__DARWIN_MAXPATHLEN];
        UniChar panelpathuni[__DARWIN_MAXPATHLEN];
        UniChar panelpathtrim[256]; // may crash here on weird cases
        size_t panelpathsz;
        m_Data->GetDirectoryPathWithTrailingSlash(panelpath);
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
        
        if(m_IsActive)
            oms::DrawStringWithBackgroundXY(panelpathtrim, 0, chars_for_path_name, path_name_start_pos, 0,
                                            context, fontcache, g_FocRegFileColor, symbs_for_path_name, g_FocFileBkColor);
        else
            oms::DrawStringXY(panelpathtrim, 0, chars_for_path_name, path_name_start_pos, 0,
                              context, fontcache, g_RegFileColor);
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw sorting mode
    {
        UniChar sort_mode[1];
        FormHumanReadableSortModeReprentation1(m_Data->GetCustomSortMode().sort, sort_mode);
        oms::DrawSingleUniCharXY(sort_mode[0], 1, 0, context, fontcache, g_HeaderInfoColor);
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw bytes in directory
    if(m_SymbWidth > 12)
    { // process bytes in directory
        UniChar bytes[128], bytestrim[128];
        size_t sz;
        FormHumanReadableBytesAndFiles128(m_Data->GetTotalBytesInDirectory(), (int)m_Data->GetTotalFilesInDirectory(), bytes, sz, true);
        int unichars = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(bytes, sz, m_SymbWidth - 2, bytestrim);
        symbs_for_bytes_in_dir = oms::CalculateSymbolsSpaceForString(bytestrim, unichars);
        bytes_in_dir_start_pos = (m_SymbWidth-symbs_for_bytes_in_dir) / 2;
        bytes_in_dir_end_pos   = bytes_in_dir_start_pos + symbs_for_bytes_in_dir;
        oms::DrawStringXY(bytestrim, 0, unichars, bytes_in_dir_start_pos, m_SymbHeight-1, context, fontcache, g_RegFileColor);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw selection if any
    if(m_Data->GetSelectedItemsCount() != 0 && m_SymbWidth > 12)
    {
        UniChar selectionbuf[128], selectionbuftrim[128];
        size_t sz;
        FormHumanReadableBytesAndFiles128(m_Data->GetSelectedItemsSizeBytes(), m_Data->GetSelectedItemsCount(), selectionbuf, sz, true);
        int unichars = oms::PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(selectionbuf, sz, m_SymbWidth - 2, selectionbuftrim);
        symbs_for_selected_bytes = oms::CalculateSymbolsSpaceForString(selectionbuftrim, unichars);
        selected_bytes_start_pos = (m_SymbWidth-symbs_for_selected_bytes) / 2;
        selected_bytes_end_pos   = selected_bytes_start_pos + symbs_for_selected_bytes;
        oms::DrawStringWithBackgroundXY(selectionbuftrim, 0, unichars,
                                        selected_bytes_start_pos, m_SymbHeight-3,
                                        context, fontcache, g_HeaderInfoColor, symbs_for_selected_bytes, g_FocFileBkColor);
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw footer data
    if(m_CursorPosition >= 0 )
    {
        UniChar buff[256];
        size_t buf_size;
            
        const auto &current_entry = raw_entries[sorted_entries[m_CursorPosition]];
        ComposeFooterFileNameForEntry(current_entry, buff, buf_size);
        int symbs = oms::CalculateUniCharsAmountForSymbolsFromRight(buff, buf_size, m_SymbWidth-2);
        oms::DrawStringXY(buff, buf_size-symbs, symbs, 1, m_SymbHeight-2, context, fontcache, g_RegFileColor);
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw frames
    oms::SetParamsForUserASCIIArt(context, m_FontCG, m_FontCT);
    oms::SetFillColor(context, g_RegFileColor);
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

- (void)drawRect:(NSRect)dirtyRect
{
    if(!m_Data) return;
    assert(m_CursorPosition < (int)m_Data->SortedDirectoryEntries().size());
    assert(m_FilesDisplayOffset >= 0);
    
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];

    // clear background
    CGContextSetRGBFillColor(context, 0.0,0.0,0.5,1);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    
    if(m_CurrentViewType == PanelViewType::ViewShort)
        [self DrawWithShortMediumWideView:context];
    else if(m_CurrentViewType == PanelViewType::ViewMedium)
        [self DrawWithShortMediumWideView:context];
    else if(m_CurrentViewType == PanelViewType::ViewWide)
        [self DrawWithShortMediumWideView:context];
    else if(m_CurrentViewType == PanelViewType::ViewFull)
        [self DrawWithFullView:context];
}

- (void)frameDidChange
{
    NSRect fr = [self frame];
    m_SymbHeight = (fr.size.height ) / FONTHEIGHT;
    m_SymbWidth = fr.size.width / FONTWIDTH;
    [self EnsureCursorIsVisible];
}

- (void) SetPanelController:(PanelController *)_controller
{
    m_Controller = _controller;
}

- (void) SetPanelData: (PanelData*) _data
{
    m_Data = _data;
    [self setNeedsDisplay:true];
}

- (void)UpdateQuickPreview
{
    if ([QuickPreview IsVisible])
    {
        int rawpos = m_Data->SortedDirectoryEntries()[m_CursorPosition];
        char path[__DARWIN_MAXPATHLEN];
        m_Data->ComposeFullPathForEntry(rawpos, path);
        NSString *nspath = [NSString stringWithUTF8String:path];
        [QuickPreview PreviewItem:nspath sender:self];
    }
}

- (void) HandlePrevFile
{
    int origpos = m_CursorPosition;
    if(m_CursorPosition > 0) m_CursorPosition--;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: origpos];
    
    [self EnsureCursorIsVisible];
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleNextFile
{
    int origpos = m_CursorPosition;
    if(m_CursorPosition + 1 < m_Data->SortedDirectoryEntries().size() ) m_CursorPosition++;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: origpos];
    
    [self EnsureCursorIsVisible];    
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandlePrevPage
{
    int origpos = m_CursorPosition;
    int max_files_shown = [self CalcMaxShownFilesForView:m_CurrentViewType];
    if(m_CursorPosition > max_files_shown) m_CursorPosition -=  max_files_shown;
    else                                   m_CursorPosition = 0;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_CursorPosition];
    if(m_FilesDisplayOffset > max_files_shown) m_FilesDisplayOffset -= max_files_shown;
    else                                       m_FilesDisplayOffset = 0;
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleNextPage
{
    int origpos = m_CursorPosition;    
    int total_files = (int)m_Data->SortedDirectoryEntries().size();
    int max_files_shown = [self CalcMaxShownFilesForView:m_CurrentViewType];
    if(m_CursorPosition + max_files_shown < total_files) m_CursorPosition += max_files_shown;
    else                                                 m_CursorPosition = total_files - 1;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_CursorPosition];    
    if(m_FilesDisplayOffset + max_files_shown*2 < total_files) m_FilesDisplayOffset += max_files_shown;
    else if(total_files - max_files_shown > 0)                 m_FilesDisplayOffset = total_files - max_files_shown;
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandlePrevColumn
{
    int origpos = m_CursorPosition;
    int files_per_column = [self CalcMaxShownFilesPerPanelForView:m_CurrentViewType];
    if(m_CursorPosition > files_per_column) m_CursorPosition -= files_per_column;
    else                                    m_CursorPosition = 0;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_CursorPosition];    
    if(m_CursorPosition < m_FilesDisplayOffset)
    {
        if(m_FilesDisplayOffset > files_per_column) m_FilesDisplayOffset -= files_per_column;
        else                                        m_FilesDisplayOffset = 0;
    }
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleNextColumn
{
    int origpos = m_CursorPosition;    
    int total_files = (int)m_Data->SortedDirectoryEntries().size();
    int files_per_column = [self CalcMaxShownFilesPerPanelForView:m_CurrentViewType];
    int max_files_shown = [self CalcMaxShownFilesForView:m_CurrentViewType];
    if(m_CursorPosition + files_per_column < total_files) m_CursorPosition += files_per_column;
    else                                                  m_CursorPosition = total_files-1;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_CursorPosition];    
    if(m_FilesDisplayOffset + max_files_shown <= m_CursorPosition)
    {
        if(m_FilesDisplayOffset + files_per_column + max_files_shown < total_files) m_FilesDisplayOffset += files_per_column;
        else if(total_files - max_files_shown > 0)                 m_FilesDisplayOffset = total_files - max_files_shown;
    }
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleFirstFile;
{
    int origpos = m_CursorPosition;    
    m_CursorPosition = 0;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_CursorPosition];    
    m_FilesDisplayOffset = 0;
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) HandleLastFile;
{
    int origpos = m_CursorPosition;    
    int total_files = (int)m_Data->SortedDirectoryEntries().size();
    int max_files_shown = [self CalcMaxShownFilesForView:m_CurrentViewType];
    m_CursorPosition = total_files - 1;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_CursorPosition];    
    if(total_files > max_files_shown) m_FilesDisplayOffset = total_files - max_files_shown;
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) EnsureCursorIsVisible
{
    if(m_CursorPosition < 0) return;

    int max_files_shown = [self CalcMaxShownFilesForView:m_CurrentViewType];
    if(m_CursorPosition < m_FilesDisplayOffset)     // check if cursor is above
    {
        m_FilesDisplayOffset = m_CursorPosition;
    }
    else if(m_CursorPosition >= m_FilesDisplayOffset + max_files_shown)     // check if cursor is below
    {
        m_FilesDisplayOffset = m_CursorPosition - max_files_shown + 1;
    }
}

- (void) SetCursorPosition:(int)_pos
{
    assert(_pos >= 0 && _pos < m_Data->SortedDirectoryEntries().size());
    if(m_CursorPosition != _pos)
    {
        m_CursorPosition = _pos;
        [self EnsureCursorIsVisible];
        [self setNeedsDisplay:true];
        [self UpdateQuickPreview];
    }
}

- (int) GetCursorPosition
{
    return m_CursorPosition;
}

- (void) DirectoryChanged:(PanelViewDirectoryChangeType)_type newcursor:(int)_cursor;
{
    if(_type == PanelViewDirectoryChangeType::GoIntoSubDir)
        [self PushDirectoryFilesOffset];
    else if(_type == PanelViewDirectoryChangeType::GoIntoParentDir)
        [self PopDirectoryFilesOffset];
    else if(_type == PanelViewDirectoryChangeType::GoIntoOtherDir)
        [self ResetDirectoryFilesOffset];

    m_CursorPosition = _cursor;
    [self EnsureCursorIsVisible];
    [self setNeedsDisplay:true];
}

// for directory traversing:
// push current when going into subdir
// pop current when going up
// reset when going into non-related place
- (void) PushDirectoryFilesOffset
{
    m_DisplayOffsetStack.push(m_FilesDisplayOffset);
}

- (void) PopDirectoryFilesOffset
{
    if(!m_DisplayOffsetStack.empty())
    {
        m_FilesDisplayOffset = m_DisplayOffsetStack.top();
        m_DisplayOffsetStack.pop();
    }
}

- (void) ResetDirectoryFilesOffset
{
    while(!m_DisplayOffsetStack.empty())
        m_DisplayOffsetStack.pop();
}

- (void) ModifierFlagsChanged:(unsigned long)_flags
{
    m_KeysModifiersFlags = _flags; // ??
    if((m_KeysModifiersFlags & NSShiftKeyMask) == 0)
    { // clear selection type when user releases SHIFT button
        m_CursorSelectionType = CursorSelectionState::No;
    }
    else
    {
        if(m_CursorSelectionType == CursorSelectionState::No)
        { // lets decide if we need to select or unselect files when user will use navigation arrows
            const auto *item = [self CurrentItem];
            if(item)
            {
                if(!item->isdotdot())
                { // regular case
                    if(item->cf_isselected()) m_CursorSelectionType = CursorSelectionState::Unselection;
                    else                     m_CursorSelectionType = CursorSelectionState::Selection;
                }
                else
                { // need to look at a first file (next to dotdot) for current representation if any.
                    if(m_Data->SortedDirectoryEntries().size() > 1)
                    { // using [1] item
                        const auto &item = m_Data->DirectoryEntries()[ m_Data->SortedDirectoryEntries()[1] ];
                        if(item.cf_isselected()) m_CursorSelectionType = CursorSelectionState::Unselection;
                        else                     m_CursorSelectionType = CursorSelectionState::Selection;
                    }
                    else
                    { // singular case - selection doesn't matter - nothing to select
                        m_CursorSelectionType = CursorSelectionState::Selection;
                    }
                }
            }
        }
    }
}

- (void) mouseDown:(NSEvent *)_event
{
    if (!m_IsActive)
        [m_Controller RequestActivation];
    
    NSPoint event_location = [_event locationInWindow];
    NSPoint local_point = [self convertPoint:event_location fromView:nil];
    
    int cursor_pos = [self CalcCursorPositionByPointInView:local_point];
    if (cursor_pos == -1) return;
    
    NSUInteger modifier_flags = _event.modifierFlags & NSDeviceIndependentModifierFlagsMask;
    if ((modifier_flags & NSShiftKeyMask) == NSShiftKeyMask)
    {
        // Select range of items with shift+click.
        // If clicked item is selected, then deselect the range instead.
        assert(cursor_pos < m_Data->SortedDirectoryEntries().size());
        int raw_pos = m_Data->SortedDirectoryEntries()[cursor_pos];
        assert(raw_pos < m_Data->DirectoryEntries().size());
        const DirectoryEntryInformation &click_entry = m_Data->DirectoryEntries()[raw_pos];
        
        bool deselect = click_entry.cf_isselected();
        [self SelectUnselectInRange:m_CursorPosition last_included:cursor_pos select:!deselect];
    }
    
    m_CursorPosition = cursor_pos;
    
    if ((modifier_flags & NSCommandKeyMask) == NSCommandKeyMask)
    {
        // Select or deselect a single item with cmd+click.
        const DirectoryEntryInformation *entry = [self CurrentItem];
        assert(entry);
        BOOL select = !entry->cf_isselected();
        [self SelectUnselectInRange:m_CursorPosition last_included:m_CursorPosition
                             select:select];
    }
    
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) mouseDragged:(NSEvent *)_event
{
    NSPoint event_location = [_event locationInWindow];
    NSPoint local_point = [self convertPoint:event_location fromView:nil];
    
    int cursor_pos = [self CalcCursorPositionByPointInView:local_point];
    if (cursor_pos == -1) return;
    
    m_CursorPosition = cursor_pos;
    [self setNeedsDisplay:true];
    [self UpdateQuickPreview];
}

- (void) mouseUp:(NSEvent *)_event
{
    if ([_event clickCount] == 2)
    {
        // Handle double click.
        NSPoint event_location = [_event locationInWindow];
        NSPoint local_point = [self convertPoint:event_location fromView:nil];
        
        int cursor_pos = [self CalcCursorPositionByPointInView:local_point];
        if (cursor_pos == -1 || cursor_pos != m_CursorPosition) return;
        [m_Controller HandleReturnButton];
    }
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    if (!m_IsActive) // will react only on active panels
        return;
    
    int idy = int([theEvent deltaY]);
    int idx = int([theEvent deltaX]/2.0); // less sensitive than vertical scrolling
    int total_files = (int)m_Data->SortedDirectoryEntries().size();
    int max_files_shown = [self CalcMaxShownFilesForView:m_CurrentViewType];
    int per_col = [self CalcMaxShownFilesPerPanelForView:m_CurrentViewType];
    int old_curpos = m_CursorPosition, old_offset = m_FilesDisplayOffset;
    if(idy != 0)
    {
        if(idy > 0)
        {
            if(m_FilesDisplayOffset > 0)    m_FilesDisplayOffset--;
            if(m_CursorPosition > 0)        m_CursorPosition--;
        }
        else
        {
            if(m_FilesDisplayOffset + max_files_shown < total_files)    m_FilesDisplayOffset++;
            if(m_CursorPosition < total_files-1)                        m_CursorPosition++;
        }
    }
    else if(idx != 0)
    {
        if(idx > 0)
        {
            if(m_FilesDisplayOffset > per_col)  m_FilesDisplayOffset -= per_col;
            else if(m_FilesDisplayOffset > 0)   m_FilesDisplayOffset=0;
            if(m_CursorPosition > per_col)      m_CursorPosition -= per_col;
            else if(m_CursorPosition > 0)       m_CursorPosition=0;
        }
        else
        {
            if(m_FilesDisplayOffset + max_files_shown < total_files)    m_FilesDisplayOffset += per_col;
            if(m_CursorPosition + per_col < total_files - 1)            m_CursorPosition += per_col;
            else if(m_CursorPosition < total_files - 1)                 m_CursorPosition = total_files - 1;
        }
    }

    if(old_curpos != m_CursorPosition || old_offset != m_FilesDisplayOffset)
        [self setNeedsDisplay:true];
}

- (const DirectoryEntryInformation*) CurrentItem
{
    if(m_CursorPosition < 0) return nullptr;
    assert(m_CursorPosition < (int)m_Data->SortedDirectoryEntries().size());
    assert(m_Data->DirectoryEntries().size() >= m_Data->SortedDirectoryEntries().size());
    return &m_Data->DirectoryEntries()[ m_Data->SortedDirectoryEntries()[m_CursorPosition] ];
}

- (int) CalcCursorPositionByPointInView:(CGPoint)_point
{
    // Developer defined constants.
    const int columns_max = 3;
    const int rows_start = 1;
    
    
    const int columns = ColumnsNumberForViewType(m_CurrentViewType);
    const int entries_in_column = [self CalcMaxShownFilesPerPanelForView:m_CurrentViewType];
    
    CGPoint point_in_chars = NSMakePoint(_point.x/FONTWIDTH, _point.y/FONTHEIGHT);

    // Check if click is in files' view area, including horizontal bottom line.
    if (point_in_chars.y < rows_start || point_in_chars.y > rows_start + entries_in_column)
        return -1;
    
    // Calculate the number of visible files.
    auto &sorted_entries = m_Data->SortedDirectoryEntries();
    const int max_files_to_show = entries_in_column * columns;
    int visible_files = (int)sorted_entries.size() - m_FilesDisplayOffset;
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
    
    return m_FilesDisplayOffset + file_number;
}

- (void) SelectUnselectInRange:(int)_start last_included:(int)_end select:(BOOL)_select
{
    // we never want to select a first (dotdot) entry
    assert(_start >= 0 && _start < m_Data->SortedDirectoryEntries().size());
    assert(_end >= 0 && _end < m_Data->SortedDirectoryEntries().size());
    if(_start > _end)
    {
        int t = _start;
        _start = _end;
        _end = t;
    }
    
    if(m_Data->DirectoryEntries()[m_Data->SortedDirectoryEntries()[_start]].isdotdot())
        ++_start; // we don't want to select or unselect a dotdot entry - they are higher than that stuff
    
    for(int i = _start; i <= _end; ++i)
        m_Data->CustomFlagsSelect(m_Data->SortedDirectoryEntries()[i], _select);
}

- (void) SelectUnselectInRange:(int)_start last_included:(int)_end
{
    assert(m_CursorSelectionType != CursorSelectionState::No);
    [self SelectUnselectInRange:_start last_included:_end
                         select:m_CursorSelectionType == CursorSelectionState::Selection];
}

- (void) ToggleViewType:(PanelViewType)_type
{
    m_CurrentViewType = _type;
    [self EnsureCursorIsVisible];
    [self setNeedsDisplay:true];
}

- (PanelViewType) GetCurrentViewType
{
    return m_CurrentViewType;
}

@end
