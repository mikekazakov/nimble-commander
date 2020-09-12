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

}
