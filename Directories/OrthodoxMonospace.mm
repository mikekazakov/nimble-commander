//
//  OrthodoxMonospace.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 07.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "OrthodoxMonospace.h"

static double g_FontWidth = 9.;
static double g_FontHeight = 20.;
static double g_TextBaseline = -4.; // baseline?

#define ISUNICODECOMBININGCHARACTER(a) (\
((a) >= 0x0300 && (a) <= 0x036F) || \
((a) >= 0x1DC0 && (a) <= 0x1DFF) || \
((a) >= 0x20D0 && (a) <= 0x20FF) || \
((a) >= 0xFE20 && (a) <= 0xFE2F) )

namespace oms
{

void SetFillColor(CGContextRef _context, const DoubleColor &_color)
{
    CGContextSetRGBFillColor(_context, _color.r, _color.g, _color.b, _color.a);
}

void DrawSingleUniChar(UniChar _s, double _x, double _y, CGContextRef _context, FontCache *_font_cache)
{
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
            CGContextShowGlyphsAtPoint(_context, _x, _y + g_FontHeight + g_TextBaseline, &p.glyph, 1);
        }
        else
        { // use current default font
            if(current_font != _font_cache->cgbasefont)
            {
                CGContextSetFont(_context, _font_cache->cgbasefont);
                current_font = _font_cache->cgbasefont;
            }
            CGContextShowGlyphsAtPoint(_context, _x, _y + g_FontHeight + g_TextBaseline, &p.glyph, 1);
        }
    }
    
    if(current_font != _font_cache->cgbasefont)
        CGContextSetFont(_context, _font_cache->cgbasefont);
}
    
void DrawSingleUniChar(UniChar _s,
                       double _x,
                       double _y,
                       CGContextRef _context,
                       FontCache *_font_cache,
                       const DoubleColor &_text_color
                       )
{
    SetFillColor(_context, _text_color);
    DrawSingleUniChar(_s, _x, _y, _context, _font_cache);
}

void DrawSingleUniCharXY(UniChar _s, int _x, int _y, CGContextRef _cont, FontCache *_cache)
{
    DrawSingleUniChar(_s, _x * g_FontWidth, _y * g_FontHeight, _cont, _cache);
}
    
void DrawSingleUniCharXY(UniChar _s, int _x, int _y, CGContextRef _cont, FontCache *_cache, const DoubleColor &_color)
{
    DrawSingleUniChar(_s, _x * g_FontWidth, _y * g_FontHeight, _cont, _cache, _color);
}

void DrawUniCharsXY(unichars_draw_batch &_batch, CGContextRef _cont, FontCache *_cache)
{
    // TODO: implement it rolled-up, it should be (?) faster
    for(int i =0; i < _batch.amount; ++i)
        DrawSingleUniChar(_batch.chars[i].c, _batch.chars[i].x * g_FontWidth, _batch.chars[i].y * g_FontHeight, _cont, _cache);
}
    
void DrawString(UniChar *_s,
                        size_t _start,    // position of a first symbol to draw
                        size_t _amount,   // number of symbols to draw. this means UniChar symbols, not visible symbols - result may be shorter
                        double _x,
                        double _y,
                        CGContextRef _context,
                        FontCache *_font_cache,
                        const DoubleColor &_text_color
                        )
{
    SetFillColor(_context, _text_color);
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
        
        // TODO: need to memorize current font to exclude redundant changes
        FontCache::Pair p = _font_cache->Get(*s);
        if( p.glyph != 0 )
        {
            if(p.font != 0)
            { // need to use a fallback font
                CGContextSetFont(_context, _font_cache->cgfallbacks[p.font]); // relying on font cache
                CGContextShowGlyphsAtPoint(_context, _x + cpos*g_FontWidth, _y + g_FontHeight + g_TextBaseline, &p.glyph, 1);
                CGContextSetFont(_context, _font_cache->cgbasefont); // clenup after
            }
            else
            { // use current default font
                CGContextShowGlyphsAtPoint(_context, _x + cpos*g_FontWidth, _y + g_FontHeight + g_TextBaseline, &p.glyph, 1);
            }
        }
    }
}
    
void DrawStringWithBackground(UniChar *_s,
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
    SetFillColor(_context, _bk_color);
    CGContextFillRect(_context, CGRectMake(_x, _y, _bk_fill_amount*g_FontWidth, g_FontHeight));
    DrawString(_s, _start, _amount, _x, _y, _context, _font_cache, _text_color);
}

void DrawStringXY(UniChar *_s,
                      size_t _start,    // position of a first symbol to draw
                      size_t _amount,   // number of symbols to draw. this means UniChar symbols, not visible symbols - result may be shorter
                      int _x,
                      int _y,
                      CGContextRef _context,
                      FontCache *_font_cache,
                      const DoubleColor &_text_color
                      )
{
    DrawString(_s, _start, _amount, _x * g_FontWidth, _y * g_FontHeight, _context, _font_cache, _text_color);
}
    
void DrawStringWithBackgroundXY(UniChar *_s,
                                    size_t _start,    // position of a first symbol to draw
                                    size_t _amount,   // number of unichars to draw, not visible symbols - result may be shorter
                                    int _x,
                                    int _y,
                                    CGContextRef _context,
                                    FontCache *_font_cache,
                                    const DoubleColor &_text_color,
                                    size_t _bk_fill_amount, // amount of symbols places to fill with _bk_color
                                    const DoubleColor &_bk_color
                                    )
{
    DrawStringWithBackground(_s, _start, _amount, _x * g_FontWidth, _y * g_FontHeight, _context, _font_cache, _text_color, _bk_fill_amount, _bk_color);
}

void SetParamsForUserReadableText(CGContextRef _context, CGFontRef _cgfont, CTFontRef _ctfont)
{
    // font settings
    CGContextSetFont(_context, _cgfont);
    CGContextSetFontSize(_context, CTFontGetSize(_ctfont));
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, false);
    CGContextSetShouldAntialias(_context, true);
        
    // font geometry
    CGAffineTransform AFF;
    AFF.a = 1;
    AFF.b = 0;
    AFF.c = 0;
    AFF.d = -1;
    AFF.tx = 0;
    AFF.ty = 0;
    CGContextSetTextMatrix(_context, AFF);
}
    
void SetParamsForUserASCIIArt(CGContextRef _context, CGFontRef _cgfont, CTFontRef _ctfont)
{
    // font settings
    CGContextSetFont(_context, _cgfont);
    CGContextSetFontSize(_context, CTFontGetSize(_ctfont));
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, false);
    CGContextSetShouldAntialias(_context, false);
        
    // font geometry
    CGAffineTransform AFF;
    AFF.a = 1;
    AFF.b = 0;
    AFF.c = 0;
    AFF.d = -1;
    AFF.tx = 0;
    AFF.ty = 0;
    CGContextSetTextMatrix(_context, AFF);
}

int CalculateSymbolsSpaceForString(const UniChar *_s, size_t _amount)
{
    int output = 0;
    for(size_t i = 0; i < _amount; ++i, ++_s)
        if(!ISUNICODECOMBININGCHARACTER(*_s))
            output += g_WCWidthTableFixedMin1[*_s];
    return output;
}
    
// calculates maximum amount of unichars that will not exceed _symb_amount when printed
// returns number of unichars that can be printed starting from 0 pos
int CalculateUniCharsAmountForSymbolsFromLeft(const UniChar *_s, size_t _unic_amount, size_t _symb_amount)
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
int CalculateUniCharsAmountForSymbolsFromRight(const UniChar *_s, size_t _unic_amount, size_t _symb_amount)
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
int PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(const UniChar *_s, size_t _unic_amount, size_t _symb_amount, UniChar *_out)
{
    const int ell_num = 3;
    assert(_symb_amount >= ell_num);
    int sizenow = oms::CalculateSymbolsSpaceForString(_s, _unic_amount);
        
    if(sizenow <= _symb_amount)
    {
        // we're fitting pretty well in desired space
        memcpy(_out, _s, sizeof(UniChar)*_unic_amount);
        return (int)_unic_amount;
    }
        
    // trim out string
    int chars = oms::CalculateUniCharsAmountForSymbolsFromRight(_s, _unic_amount, _symb_amount - ell_num);
    for(int i =0; i < ell_num; ++i)
        _out[i] = '.';
    memcpy(_out + ell_num, _s + _unic_amount - chars, sizeof(UniChar)*chars);

    return ell_num + chars;
}
    
}
