//
//  OrthodoxMonospace.h
//  Directories
//
//  Created by Michael G. Kazakov on 07.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <Cocoa/Cocoa.h>
#include <assert.h>

class FontCache;

struct DoubleColor
{
    double r,g,b,a;
    DoubleColor(double _r, double _g, double _b, double _a):
    r(_r), g(_g), b(_b), a(_a) {}
    DoubleColor():
    r(0.), g(0.), b(0.), a(1.) {}
    DoubleColor(NSColor *_c):
        r(0.), g(0.), b(0.), a(1.)
    {
        [[_c colorUsingColorSpace:[NSColorSpace genericRGBColorSpace]] getRed:&r green:&g blue:&b alpha:&a];
    }
    void Set(CGContextRef _context) const {
        CGContextSetRGBFillColor(_context, r, g, b, a);
    };
    inline bool operator==(const DoubleColor& _r) const {
        return memcmp(this, &_r, sizeof(*this)) == 0;
    }
    inline bool operator!=(const DoubleColor& _r) const {
        return memcmp(this, &_r, sizeof(*this)) != 0;
    }
};

namespace oms
{

struct unichars_draw_batch
{
    enum {max = 1024*8};
    struct{
        UniChar c;
        short x;
        short y;
    } chars[max];
    int amount;
    inline unichars_draw_batch():amount(0){};
    inline void clear() {amount = 0;}
    inline void put(UniChar _c, short _x, short _y)
    {
        assert(amount < max);
        chars[amount++] = {_c, _x, _y};
    }
};

    
// graphic configuration
void SetFillColor(CGContextRef _cont, const DoubleColor &_color);
void SetParamsForUserReadableText(CGContextRef _context, FontCache *_cache);
void SetParamsForUserASCIIArt(CGContextRef _context, FontCache *_cache);
    
// drawing routines
void DrawSingleUniChar(UniChar _s, double _x, double _y, CGContextRef _cont, FontCache *_cache, const DoubleColor &_color);
void DrawSingleUniChar(UniChar _s, double _x, double _y, CGContextRef _cont, FontCache *_cache);
void DrawSingleUniCharXY(UniChar _s, int _x, int _y, CGContextRef _cont, FontCache *_cache, const DoubleColor &_color, const DoubleColor &_bk_color);    
void DrawSingleUniCharXY(UniChar _s, int _x, int _y, CGContextRef _cont, FontCache *_cache, const DoubleColor &_color);
void DrawSingleUniCharXY(UniChar _s, int _x, int _y, CGContextRef _cont, FontCache *_cache);
void DrawUniCharsXY(unichars_draw_batch &_batch, CGContextRef _cont, FontCache *_cache);
void DrawString(UniChar *_s,
                size_t _start,    // position of a first symbol to draw
                size_t _amount,   // number of symbols to draw. this means UniChar symbols, not visible symbols - result may be shorter
                double _x,
                double _y,
                CGContextRef _context,
                FontCache *_font_cache,
                const DoubleColor &_text_color
                );
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
                );
void DrawStringXY(UniChar *_s,
                size_t _start,    // position of a first symbol to draw
                size_t _amount,   // number of symbols to draw. this means UniChar symbols, not visible symbols - result may be shorter
                int _x,
                int _y,
                CGContextRef _context,
                FontCache *_font_cache,
                const DoubleColor &_text_color
                );
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
                );

// unichar strings processing
int CalculateSymbolsSpaceForString(const UniChar *_s, size_t _amount);
    // calculates amount of monospace characters need to accommodate whole input string

int CalculateUniCharsAmountForSymbolsFromLeft(const UniChar *_s, size_t _unic_amount, size_t _symb_amount);
    // calculates maximum amount of unichars that will not exceed _symb_amount when printed
    // returns number of unichars that can be printed starting from 0 pos

int CalculateUniCharsAmountForSymbolsFromRight(const UniChar *_s, size_t _unic_amount, size_t _symb_amount);
    // calculates maximum amount of unichars that will not exceed _symb_amount when printed
    // returns number of unichar that can be printed started for _unic_amount - RET

int PackUniCharsIntoFixedLengthVisualWithLeftEllipsis(const UniChar *_s, size_t _unic_amount, size_t _symb_amount, UniChar *_out);
    // returns a number of actual unichars in _out
    // requires that _symb_amount should be >= 3, otherwise it's meaningless

    
    
}
