// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/Encodings.h>
#include "FontCache.h"

#include <string>

namespace oms
{

using nc::utility::FontCache;
        
// graphic configuration
void SetParamsForUserReadableText(CGContextRef _context, FontCache &_cache);
void SetParamsForUserASCIIArt(CGContextRef _context, FontCache &_cache);
    
// drawing routines
void DrawSingleUniChar(uint32_t _s, double _x, double _y, CGContextRef _cont, FontCache &_cache);
void DrawSingleUniCharXY(uint32_t _s, int _x, int _y, CGContextRef _cont, FontCache &_cache);

// unichar strings processing

inline bool IsUnicodeCombiningCharacter(uint32_t a)
{
    return
    (a >= 0x0300 && a <= 0x036F) ||
    (a >= 0x1DC0 && a <= 0x1DFF) ||
    (a >= 0x20D0 && a <= 0x20FF) ||
    (a >= 0xFE20 && a <= 0xFE2F) ;
}
    
extern uint32_t __g_PossibleCompositionEvidence[2048];
inline bool CanCharBeTheoreticallyComposed(uint32_t _c) noexcept
{
    if(_c >= 0x10000)
        return false;
    return (__g_PossibleCompositionEvidence[_c / 32] >> (_c % 32)) & 1;
}
 
extern uint32_t __g_WCWidthTableIsFullSize[2048];
inline unsigned char WCWidthMin1(uint32_t _c) noexcept
{
    if(_c < 0x10000)
        return ((__g_WCWidthTableIsFullSize[_c / 32] >> (_c % 32)) & 1) ? 2 : 1;
    else
        return
        (_c >= 0x10000 && _c <= 0x1fffd) ||
        (_c >= 0x20000 && _c <= 0x2fffd) ||
        (_c >= 0x30000 && _c <= 0x3fffd) ?
        2 : 1;
}
    
}
