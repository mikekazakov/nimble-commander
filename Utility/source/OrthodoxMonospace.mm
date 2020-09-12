// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/FontCache.h>
#include "OrthodoxMonospace.h"

namespace oms
{

void DrawSingleUniChar(uint32_t _s, double _x, double _y, CGContextRef _context, FontCache &_cache)
{
    FontCache::Pair p = _cache.Get(_s);
    if( p.glyph == 0 )
        return;

    CGPoint pos{0., 0.};
    CGContextSetTextPosition(_context, _x, _y + _cache.Height() - _cache.Descent());
    CTFontDrawGlyphs(_cache.Font(p.font), &p.glyph, &pos, 1, _context);
}

void DrawSingleUniCharXY(uint32_t _s, int _x, int _y, CGContextRef _cont, FontCache &_cache)
{
    DrawSingleUniChar(_s, _x * _cache.Width(), _y * _cache.Height(), _cont, _cache);
}

void SetParamsForUserReadableText(CGContextRef _context, [[maybe_unused]] FontCache &_cache)
{
    // font settings
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, true);
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
    
void SetParamsForUserASCIIArt(CGContextRef _context, [[maybe_unused]] FontCache &_cache)
{
    // font settings
    CGContextSetTextDrawingMode(_context, kCGTextFill);
    CGContextSetShouldSmoothFonts(_context, true);
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
    
}
