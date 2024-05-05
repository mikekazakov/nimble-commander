// Copyright (C) 2013-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/Encodings.h>
#include <CoreGraphics/CoreGraphics.h>

#include <string>

namespace nc::term {

// graphic configuration
void SetParamsForUserReadableText(CGContextRef _context);
void SetParamsForUserASCIIArt(CGContextRef _context);

} // namespace nc::term
