// Copyright (C) 2013-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "OrthodoxMonospace.h"

namespace nc::term {

void SetParamsForUserReadableText(CGContextRef _context)
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

void SetParamsForUserASCIIArt(CGContextRef _context)
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

} // namespace nc::term
