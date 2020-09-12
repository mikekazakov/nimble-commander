// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/Encodings.h>
#include <Utility/FontCache.h>

#include <string>

namespace nc::term
{
        
// graphic configuration
void SetParamsForUserReadableText(CGContextRef _context,
                                  utility::FontCache &_cache);
void SetParamsForUserASCIIArt(CGContextRef _context,
                              utility::FontCache &_cache);
    
// drawing routines
void DrawSingleUniChar(uint32_t _s,
                       double _x,
                       double _y,
                       CGContextRef _context,
                       utility::FontCache &_cache);
void DrawSingleUniCharXY(uint32_t _s,
                         int _x,
                         int _y,
                         CGContextRef _context,
                         utility::FontCache &_cache);

}
