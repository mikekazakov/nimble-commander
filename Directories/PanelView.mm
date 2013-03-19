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

#include "wcwidth.h" // remove me!


#define FONTSIZE 15.0f
#define FONTWIDTH 9
#define FONTHEIGHT 20
#define DRAWOFFSETX 9
#define DRAWOFFSETY 20
#define pX(a) ((a)*FONTWIDTH)
#define pY(a) ((a)*FONTHEIGHT)

#define ISUNICODECOMBININGCHARACTER(a) (\
    ((a) >= 0x0300 && (a) <= 0x036F) || \
    ((a) >= 0x1DC0 && (a) <= 0x1DFF) || \
    ((a) >= 0x20D0 && (a) <= 0x20FF) || \
    ((a) >= 0xFE20 && (a) <= 0xFE2F) )

struct DoubleColor
{
    double r,g,b,a;
    DoubleColor(double _r, double _g, double _b, double _a):
        r(_r), g(_g), b(_b), a(_a) {}
};

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




static int CalculateSymbolsSpaceForString(const UniChar *_s, size_t _amount)
{
    int output = 0;
    for(size_t i = 0; i < _amount; ++i, ++_s)
    {
        bool iscomb = ISUNICODECOMBININGCHARACTER(*_s);

        if(!iscomb)
        {
            output += g_WCWidthTableFixedMin1[*_s];
        }
    }
    return output;
}

// calculates maximum amount of unichars that will not exceed _symb_amount when printed
// returns number of unichars that can be printed starting from 0 pos
static int CalculateUniCharsAmountForSymbolsFromLeft(const UniChar *_s, size_t _unic_amount, size_t _symb_amount)
{
    int cpos = 0, i=0, posdelta = 1;
    for(; i < _unic_amount; ++i, ++_s)
    {
        bool iscomb = ISUNICODECOMBININGCHARACTER(*_s);
        if(!iscomb)
        {
            if(cpos == _symb_amount)
            {
                --i;
                break;
            }
            if(cpos + posdelta > _symb_amount) // for width = 2 case
            {
                --i;
                break;
            }
            cpos += posdelta;
            posdelta = g_WCWidthTableFixedMin1[*_s];
        }
    }
    return i+1;
}

// calculates maximum amount of unichars that will not exceed _symb_amount when printed
// returns number of unichar that can be printed started for _unic_amount - RET
static int CalculateUniCharsAmountForSymbolsFromRight(const UniChar *_s, size_t _unic_amount, size_t _symb_amount)
{
    int cpos = 0, i=(int)_unic_amount-1;
    _s += i;
    for(;; --i, --_s)
    {
        bool iscomb = ISUNICODECOMBININGCHARACTER(*_s);        

        if(!iscomb)
        {
            if(cpos + g_WCWidthTableFixedMin1[*_s] > _symb_amount)
                break;
            cpos += g_WCWidthTableFixedMin1[*_s];
        }
        
        if(cpos == _symb_amount || i == 0) break;
    }
    
    return (int)_unic_amount - i;
}

// returns a number of actual unichars in _out
// requires that _symb_amount should be >= 3, otherwise it's meaningless
static int PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(const UniChar *_s, size_t _unic_amount, size_t _symb_amount, UniChar *_out)
{
    const int ell_num = 3;
    assert(_symb_amount >= ell_num);
    int sizenow = CalculateSymbolsSpaceForString(_s, _unic_amount);
    
    if(sizenow <= _symb_amount)
    {
        // we're fitting pretty well in desired space
        memcpy(_out, _s, sizeof(UniChar)*_unic_amount);
        return (int)_unic_amount;
    }
    
    // trim out string
    int chars = CalculateUniCharsAmountForSymbolsFromRight(_s, _unic_amount, _symb_amount - ell_num);
    for(int i =0; i < ell_num; ++i)
        _out[i] = '.';
    memcpy(_out + ell_num, _s + _unic_amount - chars, sizeof(UniChar)*chars);

    return ell_num + chars;
}

static inline void DrawSingleUniChar(UniChar _s,
                                     double _x,
                                     double _y,
                                     CGContextRef _context,
                                     FontCache *_font_cache,
                                     const DoubleColor &_text_color
                                     )
{
    CGContextSetRGBFillColor(_context,
                             _text_color.r,
                             _text_color.g,
                             _text_color.b,
                             _text_color.a);

    CGFontRef current_font = _font_cache->cgbasefont;
    
    FontCache::Pair p = _font_cache->Get(_s);
    if( p.glyph != 0 )
    {
        if(p.font != 0)
        { // need to use a fallback font
            if(_font_cache->cgfallbacks[p.font] != current_font)
            {
                CGContextSetFont(_context, _font_cache->cgfallbacks[p.font]);
                current_font = _font_cache->cgfallbacks[p.font];
            }
            CGContextShowGlyphsAtPoint(_context, _x, _y + FONTHEIGHT - 4, &p.glyph, 1);
        }
        else
        { // use current default font
            if(current_font != _font_cache->cgbasefont)
            {
                CGContextSetFont(_context, _font_cache->cgbasefont);
                current_font = _font_cache->cgbasefont;
            }
            CGContextShowGlyphsAtPoint(_context, _x, _y + FONTHEIGHT - 4, &p.glyph, 1);
        }
    }

    if(current_font != _font_cache->cgbasefont)
        CGContextSetFont(_context, _font_cache->cgbasefont);
}

static void DrawString(UniChar *_s,
                  size_t _start,    // position of a first symbol to draw
                  size_t _amount,   // number of symbols to draw. this means UniChar symbols, not visible symbols - result may be shorter
                  double _x,
                  double _y,
                  CGContextRef _context,
                  FontCache *_font_cache,
                  const DoubleColor &_text_color
                  )
{
    CGContextSetRGBFillColor(_context,
                             _text_color.r,
                             _text_color.g,
                             _text_color.b,
                             _text_color.a);
    UniChar *s = _s + _start;
    
    int cpos = -1; // output character position
    int posdelta = 1;
    for(size_t i = 0; i < _amount; ++i, ++s)
    {
        if(!*s) continue;

        bool iscomb = ISUNICODECOMBININGCHARACTER(*s);

        if(!iscomb)
        {
            cpos+=posdelta;
            posdelta = g_WCWidthTableFixedMin1[*s];
        }

        FontCache::Pair p = _font_cache->Get(*s);
        if( p.glyph != 0 )
        {
            if(p.font != 0)
            { // need to use a fallback font
                CGContextSetFont(_context, _font_cache->cgfallbacks[p.font]); // relying on font cache
                CGContextShowGlyphsAtPoint(_context, _x + cpos*FONTWIDTH, _y + FONTHEIGHT - 4, &p.glyph, 1);                
                CGContextSetFont(_context, _font_cache->cgbasefont); // clenup after
            }
            else
            { // use current default font
                CGContextShowGlyphsAtPoint(_context, _x + cpos*FONTWIDTH, _y + FONTHEIGHT - 4, &p.glyph, 1);
            }
        }
    }
}

static void DrawStringWithBackground(UniChar *_s,
                       size_t _start,    // position of a first symbol to draw
                       size_t _amount,   // number of unichars to draw, not visible symbols - result may be shorter
                       double _x,
                       double _y,
                       CGContextRef _context,
                       FontCache *_font_cache,
                       const DoubleColor &_text_color,
                       size_t _bk_fill_amount, // amount of symbols places to fill with _bk_color
                       const DoubleColor &_bk_color
                       )
{
    CGContextSetRGBFillColor(_context,
                             _bk_color.r,
                             _bk_color.g,
                             _bk_color.b,
                             _bk_color.a);
    CGContextFillRect(_context, CGRectMake(_x, _y, _bk_fill_amount*FONTWIDTH, FONTHEIGHT));
    DrawString(_s, _start, _amount, _x, _y, _context, _font_cache, _text_color);
}

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
            
            if( _dirent->isdotdot() ) strcpy(buf, "   DIR");
            else                      strcpy(buf, "    UP");
            
            for(int i = 0; i < 6; ++i) _out[i] = buf[i];
        }
    }
    else
    {
        FormHumanReadableSizeRepresentation6(_dirent->size, _out);
    }
}

static void FormHumanReadableSizeReprentationForSortMode1(PanelSortMode::Mode _mode, UniChar _out[1])
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
    PanelData       *m_Data;
    FontCache       *m_FontCache;
    int             m_SymbWidth;
    int             m_SymbHeight;
    int             m_FilesDisplayOffset; // number of a first file which appears on the panel view, on the top
    std::stack<int> m_DisplayOffsetStack;
    int             m_CursorPosition;
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
        m_FontCache = new FontCache(m_FontCT);
        m_FilesDisplayOffset = 0;
        m_CursorPosition = 0;
        m_CurrentViewType = ViewShort;
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

- (NSSize)intrinsicContentSize
{
    return NSMakeSize(NSViewNoInstrinsicMetric, NSViewNoInstrinsicMetric);
}

- (int)CalcMaxShownFilesForView:(PanelViewType) _view
{
    if(_view == ViewShort)
    {
        int columns = 3;
        int entries_in_column = [self CalcMaxShownFilesPerPanelForView:_view];
        return entries_in_column * columns;
    }
    else
        assert(0);
    return 1;
}

- (int)CalcMaxShownFilesPerPanelForView:(PanelViewType) _view
{
    if(_view == ViewShort)
        return m_SymbHeight - 4;
    else
        assert(0);
    return 1;
}

- (void)SetParamsForUserReadableText:(CGContextRef) context
{
    // font settings
    CGContextSetFont(context, m_FontCG);
    CGContextSetFontSize(context, CTFontGetSize(m_FontCT));
    CGContextSetTextDrawingMode(context, kCGTextFill);
    CGContextSetShouldSmoothFonts(context, false);
    CGContextSetShouldAntialias(context, true);

    // font geometry
    CGAffineTransform AFF;
    AFF.a = 1;
    AFF.b = 0;
    AFF.c = 0;
    AFF.d = -1;
    AFF.tx = 0;
    AFF.ty = 0;
    CGContextSetTextMatrix( (CGContextRef)context, AFF);
}

- (void)SetParamsForASCIIArt:(CGContextRef) context
{
    // font settings
    CGContextSetFont(context, m_FontCG);
    CGContextSetFontSize(context, CTFontGetSize(m_FontCT));
    CGContextSetTextDrawingMode(context, kCGTextFill);
    CGContextSetShouldSmoothFonts(context, false);
    CGContextSetShouldAntialias(context, false);
    
    // font geometry
    CGAffineTransform AFF;
    AFF.a = 1;
    AFF.b = 0;
    AFF.c = 0;
    AFF.d = -1;
    AFF.tx = 0;
    AFF.ty = 0;
    CGContextSetTextMatrix( (CGContextRef)context, AFF);
}

- (void)DrawWithShortView:(CGContextRef) context
{
    // layout preparation
    const int columns = 3;
    int entries_in_column = [self CalcMaxShownFilesPerPanelForView:ViewShort];
    int max_files_to_show = entries_in_column * columns;
    int column_width = (m_SymbWidth - 1) / columns;
    int columns_rest = m_SymbWidth - 1 - column_width*columns;
    int columns_width[columns] = {column_width, column_width, column_width};
    if(columns_rest) { columns_width[2]++;  columns_rest--; }
    if(columns_rest) { columns_width[1]++;  columns_rest--; }
    
    auto &raw_entries = m_Data->DirectoryEntries();
    auto &sorted_entries = m_Data->SortedDirectoryEntries();
    UniChar buff[256];
    bool draw_path_name = false, draw_selected_bytes = false;
    int symbs_for_path_name = 0, path_name_start_pos = 0, path_name_end_pos = 0;
    int symbs_for_selected_bytes = 0, selected_bytes_start_pos = 0, selected_bytes_end_pos = 0;
    int symbs_for_bytes_in_dir = 0, bytes_in_dir_start_pos = 0, bytes_in_dir_end_pos = 0;
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw file names
    {
    int n=0,X,Y;
    [self SetParamsForUserReadableText:context];
    for(auto i = sorted_entries.begin() + m_FilesDisplayOffset; i < sorted_entries.end(); ++i, ++n)
    {
        if(n >= max_files_to_show) break; // draw only visible
        const auto& current = raw_entries[*i];
        
        memset(buff, 0, sizeof(buff));
        size_t buf_size = 0;
        
        InterpretUTF8BufferAsUniChar( current.name(), current.namelen, buff, &buf_size, 0xFFFD);
        
        int CN = n / entries_in_column;
        if(CN == 0) X = 1;
        else if(CN == 1) X = columns_width[0] + 1;
        else X = columns_width[0] + columns_width[1] + 1;
        Y = (n % entries_in_column + 1);
        
        if((m_FilesDisplayOffset + n != m_CursorPosition) || !m_IsActive)
            DrawString(buff, 0, CalculateUniCharsAmountForSymbolsFromLeft(buff, buf_size, columns_width[CN] - 1),
                pX(X), pY(Y), context, m_FontCache, GetDirectoryEntryTextColor(current, false));
        else // cursor
            DrawStringWithBackground(buff, 0, CalculateUniCharsAmountForSymbolsFromLeft(buff, buf_size, columns_width[CN] - 1),
                pX(X), pY(Y), context, m_FontCache, GetDirectoryEntryTextColor(current, true), columns_width[CN] - 1, g_FocFileBkColor);
    }
    }
    
    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw header and footer data
    {
    const auto &current_entry = raw_entries[sorted_entries[m_CursorPosition]];
    UniChar time_info[14], size_info[6], sort_mode[1];
    size_t buf_size = 0;
    FormHumanReadableTimeRepresentation14(current_entry.mtime, time_info);
    FormHumanReadableSizeReprentationForDirEnt6(&current_entry, size_info);
    FormHumanReadableSizeReprentationForSortMode1(m_Data->GetCustomSortMode().sort, sort_mode);

    InterpretUTF8BufferAsUniChar( current_entry.name(), current_entry.namelen, buff, &buf_size, 0xFFFD);
    
    // draw sorting mode in left-upper corner
    DrawSingleUniChar(sort_mode[0], pX(1), pY(0), context, m_FontCache, g_HeaderInfoColor);

    if(m_SymbWidth > 14)
    {   // need to draw a path name
        char panelpath[__DARWIN_MAXPATHLEN];
        UniChar panelpathuni[__DARWIN_MAXPATHLEN];
        UniChar panelpathtrim[256]; // may crash here on weird cases
        size_t panelpathsz;
        draw_path_name = true;
        m_Data->GetDirectoryPathWithTrailingSlash(panelpath);
        InterpretUTF8BufferAsUniChar( (unsigned char*)panelpath, strlen(panelpath), panelpathuni, &panelpathsz, 0xFFFD);
        int chars_for_path_name = PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(panelpathuni, panelpathsz, m_SymbWidth - 7, panelpathtrim);

        // add prefix and postfix - " "
        memmove(panelpathtrim+1, panelpathtrim, sizeof(UniChar)*chars_for_path_name);
        panelpathtrim[0] = ' ';
        panelpathtrim[chars_for_path_name+1] = ' ';
        chars_for_path_name += 2;
        symbs_for_path_name = CalculateSymbolsSpaceForString(panelpathtrim, chars_for_path_name);
        path_name_start_pos = (m_SymbWidth-symbs_for_path_name) / 2;
        path_name_end_pos = (m_SymbWidth-symbs_for_path_name) / 2 + symbs_for_path_name;
        
        if(m_IsActive)
            DrawStringWithBackground(panelpathtrim, 0, chars_for_path_name, pX(path_name_start_pos), pY(0),
                                        context, m_FontCache, g_FocRegFileColor, symbs_for_path_name, g_FocFileBkColor);
        else
            DrawString(panelpathtrim, 0, chars_for_path_name, pX(path_name_start_pos), pY(0),
                                        context, m_FontCache, g_RegFileColor);
    }

    // footer info        
    if(m_SymbWidth > 2 + 14 + 6)
    {   // draw current entry time info, size info and maybe filename
        DrawString(time_info, 0, 14, pX(m_SymbWidth - 15), pY(m_SymbHeight - 2), context, m_FontCache, g_RegFileColor);
        DrawString(size_info, 0, 6, pX(m_SymbWidth - 15 - 7), pY(m_SymbHeight - 2), context, m_FontCache, g_RegFileColor);
        
        int symbs_for_name = m_SymbWidth - 2 - 14 - 6 - 2;
        if(symbs_for_name > 0)
        {
            int symbs = CalculateUniCharsAmountForSymbolsFromRight(buff, buf_size, symbs_for_name);
            DrawString(buff, buf_size-symbs, symbs, pX(1), pY(m_SymbHeight-2), context, m_FontCache, g_RegFileColor);
        }
    }
    else if(m_SymbWidth >= 2 + 6)
    {   // draw current entry size info and maybe filename
        DrawString(size_info, 0, 6, pX(1), pY(m_SymbHeight - 2), context, m_FontCache, g_RegFileColor);
        int symbs_for_name = m_SymbWidth - 2 - 6 - 1;
        if(symbs_for_name > 0)
        {
            int symbs = CalculateUniCharsAmountForSymbolsFromLeft(time_info, 14, symbs_for_name);
            DrawString(time_info, 0, symbs, pX(8), pY(m_SymbHeight-2), context, m_FontCache, g_RegFileColor);
        }
    }
        
    if(m_Data->GetSelectedItemsCount() != 0 && m_SymbWidth > 12)
    { // process selection if any
        UniChar selectionbuf[128], selectionbuftrim[128];
        size_t sz;
        draw_selected_bytes = true;
        FormHumanReadableBytesAndFiles128(m_Data->GetSelectedItemsSizeBytes(), m_Data->GetSelectedItemsCount(), selectionbuf, sz, true);
        int unichars = PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(selectionbuf, sz, m_SymbWidth - 2, selectionbuftrim);
        symbs_for_selected_bytes = CalculateSymbolsSpaceForString(selectionbuftrim, unichars);
        selected_bytes_start_pos = (m_SymbWidth-symbs_for_selected_bytes) / 2;
        selected_bytes_end_pos   = selected_bytes_start_pos + symbs_for_selected_bytes;
        DrawStringWithBackground(selectionbuftrim, 0, unichars,
                                 pX(selected_bytes_start_pos), pY(m_SymbHeight-3),
                                 context, m_FontCache, g_HeaderInfoColor, symbs_for_selected_bytes, g_FocFileBkColor);
    }

    if(m_SymbWidth > 12)
    { // process bytes in directory
        UniChar bytes[128], bytestrim[128];
        size_t sz;
        FormHumanReadableBytesAndFiles128(m_Data->GetTotalBytesInDirectory(), (int)m_Data->GetTotalFilesInDirectory(), bytes, sz, true);
        int unichars = PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(bytes, sz, m_SymbWidth - 2, bytestrim);
        symbs_for_bytes_in_dir = CalculateSymbolsSpaceForString(bytestrim, unichars);
        bytes_in_dir_start_pos = (m_SymbWidth-symbs_for_bytes_in_dir) / 2;
        bytes_in_dir_end_pos   = bytes_in_dir_start_pos + symbs_for_bytes_in_dir;
        DrawString(bytestrim, 0, unichars,
                                 pX(bytes_in_dir_start_pos), pY(m_SymbHeight-1),
                                 context, m_FontCache, g_RegFileColor);
    }

    }

    /////////////////////////////////////////////////////////////////////////////////////////////////
    // draw frames
    [self SetParamsForASCIIArt:context];
    DrawSingleUniChar(0x2554, pX(0), pY(0), context, m_FontCache, g_RegFileColor);                              // ╔
    for(int i = 1; i < m_SymbHeight - 1; ++i)
        if(i != m_SymbHeight - 3)
        {
            DrawSingleUniChar(0x2551, pX(0), pY(i), context, m_FontCache, g_RegFileColor);                      // ║
            DrawSingleUniChar(0x2551, pX(m_SymbWidth-1), pY(i), context, m_FontCache, g_RegFileColor);          // ║
        }
        else
        {
            DrawSingleUniChar(0x255F, pX(0), pY(i), context, m_FontCache, g_RegFileColor);                      // ╟
            DrawSingleUniChar(0x2562, pX(m_SymbWidth-1), pY(i), context, m_FontCache, g_RegFileColor);          // ╢
        }
    DrawSingleUniChar(0x255A, pX(0), pY(m_SymbHeight-1), context, m_FontCache, g_RegFileColor);                 // ╚
    DrawSingleUniChar(0x255D, pX(m_SymbWidth-1), pY(m_SymbHeight-1), context, m_FontCache, g_RegFileColor);     // ╝
    DrawSingleUniChar(0x2557, pX(m_SymbWidth-1), pY(0), context, m_FontCache, g_RegFileColor);                  // ╗
    if(!draw_path_name || columns_width[0] < path_name_start_pos || columns_width[0] >= path_name_end_pos)
        DrawSingleUniChar(0x2564, pX(columns_width[0]), pY(0), context, m_FontCache, g_RegFileColor);               // ╤
    if(!draw_path_name || columns_width[0]+columns_width[1] < path_name_start_pos || columns_width[0]+columns_width[1] >= path_name_end_pos)
        DrawSingleUniChar(0x2564, pX(columns_width[0]+columns_width[1]), pY(0), context, m_FontCache, g_RegFileColor);             // ╤
    for(int i = 1; i < m_SymbHeight - 3; ++i)
    {   DrawSingleUniChar(0x2502, pX(columns_width[0]), pY(i), context, m_FontCache, g_RegFileColor);                          // │
        DrawSingleUniChar(0x2502, pX(columns_width[0]+columns_width[1]), pY(i), context, m_FontCache, g_RegFileColor); }       // │
    for(int i = 1; i < m_SymbWidth - 1; ++i)
    {
        if( (i != columns_width[0]) && (i != columns_width[0] + columns_width[1]))
        {
            if( (i!=1) &&
               (!draw_path_name || i < path_name_start_pos || i >= path_name_end_pos))
                DrawSingleUniChar(0x2550, pX(i), pY(0), context, m_FontCache, g_RegFileColor);                      // ═
            if(!draw_selected_bytes || i < selected_bytes_start_pos || i >= selected_bytes_end_pos )
                DrawSingleUniChar(0x2500, pX(i), pY(m_SymbHeight-3), context, m_FontCache, g_RegFileColor);         // ─
            
        }
        else
        {
            if(!draw_selected_bytes || i < selected_bytes_start_pos || i >= selected_bytes_end_pos )
                DrawSingleUniChar(0x2534, pX(i), pY(m_SymbHeight-3), context, m_FontCache, g_RegFileColor);         // ┴
        }
        if(i < bytes_in_dir_start_pos || i >= bytes_in_dir_end_pos)
            DrawSingleUniChar(0x2550, pX(i), pY(m_SymbHeight-1), context, m_FontCache, g_RegFileColor);                      // ═
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    if(!m_Data) return;
    assert(m_CursorPosition < m_Data->SortedDirectoryEntries().size());
    
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];

    // clear background
    CGContextSetRGBFillColor(context, 0.0,0.0,0.5,1);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
    
    [self DrawWithShortView:context];
}

- (void)frameDidChange
{
    NSRect fr = [self frame];
    m_SymbHeight = (fr.size.height ) / FONTHEIGHT;
    m_SymbWidth = fr.size.width / FONTWIDTH;
    [self EnsureCursorIsVisible];
}

- (void) SetPanelData: (PanelData*) _data
{
    m_Data = _data;
    [self setNeedsDisplay:true];
}

- (void) HandlePrevFile
{
    int origpos = m_CursorPosition;
    if(m_CursorPosition > 0) m_CursorPosition--;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: origpos];
    
    [self EnsureCursorIsVisible];
    [self setNeedsDisplay:true];
}

- (void) HandleNextFile
{
    int origpos = m_CursorPosition;
    if(m_CursorPosition + 1 < m_Data->DirectoryEntries().size() ) m_CursorPosition++;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: origpos];
    
    [self EnsureCursorIsVisible];    
    [self setNeedsDisplay:true];
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
}

- (void) HandleNextPage
{
    int origpos = m_CursorPosition;    
    int total_files = (int)m_Data->DirectoryEntries().size();
    int max_files_shown = [self CalcMaxShownFilesForView:m_CurrentViewType];
    if(m_CursorPosition + max_files_shown < total_files) m_CursorPosition += max_files_shown;
    else                                                 m_CursorPosition = total_files - 1;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_CursorPosition];    
    if(m_FilesDisplayOffset + max_files_shown*2 < total_files) m_FilesDisplayOffset += max_files_shown;
    else if(total_files - max_files_shown > 0)                 m_FilesDisplayOffset = total_files - max_files_shown;
    [self setNeedsDisplay:true];
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
}

- (void) HandleNextColumn
{
    int origpos = m_CursorPosition;    
    int total_files = (int)m_Data->DirectoryEntries().size();    
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
}

- (void) HandleFirstFile;
{
    int origpos = m_CursorPosition;    
    m_CursorPosition = 0;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_CursorPosition];    
    m_FilesDisplayOffset = 0;
    [self setNeedsDisplay:true];
}

- (void) HandleLastFile;
{
    int origpos = m_CursorPosition;    
    int total_files = (int)m_Data->DirectoryEntries().size();
    int max_files_shown = [self CalcMaxShownFilesForView:m_CurrentViewType];
    m_CursorPosition = total_files - 1;
    if(m_CursorSelectionType != CursorSelectionState::No)
        [self SelectUnselectInRange:origpos last_included: m_CursorPosition];    
    if(total_files > max_files_shown) m_FilesDisplayOffset = total_files - max_files_shown;
    [self setNeedsDisplay:true];
}

- (void) EnsureCursorIsVisible
{
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
    assert(_pos >= 0 && _pos < m_Data->DirectoryEntries().size());
    m_CursorPosition = _pos;
    [self EnsureCursorIsVisible];
}

- (int) GetCursorPosition
{
    return m_CursorPosition;
}

- (void) DirectoryChanged:(int) _new_curpos Type:(DirectoryChangeType)_type
{
    if(_type == GoIntoSubDir)
        [self PushDirectoryFilesOffset];
    else if(_type == GoIntoParentDir)
        [self PopDirectoryFilesOffset];
    else assert(0); // implement me later
        
    m_CursorPosition = _new_curpos;
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
            const auto &item = [self CurrentItem];
            if(!item.isdotdot())
            { // regular case
                if(item.cf_isselected()) m_CursorSelectionType = CursorSelectionState::Unselection;
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

- (const DirectoryEntryInformation&) CurrentItem
{
    assert(m_CursorPosition < m_Data->DirectoryEntries().size());
    assert(m_Data->DirectoryEntries().size() == m_Data->SortedDirectoryEntries().size());
    return m_Data->DirectoryEntries()[ m_Data->SortedDirectoryEntries()[m_CursorPosition] ];
}

- (void) SelectUnselectInRange:(int)_start last_included:(int)_end
{
    assert(m_CursorSelectionType != CursorSelectionState::No);
    // we never want to select a first (dotdot) entry
    assert(_start >= 0 && _start < m_Data->DirectoryEntries().size());
    assert(_end >= 0 && _end < m_Data->DirectoryEntries().size());
    if(_start > _end)
    {
        int t = _start;
        _start = _end;
        _end = t;
    }
    
    if(m_Data->DirectoryEntries()[m_Data->SortedDirectoryEntries()[_start]].isdotdot())
        ++_start; // we don't want to select or unselect a dotdot entry - they are higher than that stuff

    for(int i = _start; i <= _end; ++i)
        m_Data->CustomFlagsSelect( m_Data->SortedDirectoryEntries()[i],
                                  m_CursorSelectionType == CursorSelectionState::Selection);
}


@end
