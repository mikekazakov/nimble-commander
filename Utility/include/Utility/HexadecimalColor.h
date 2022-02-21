// Copyright (C) 2015-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <stdint.h>
#include <string>
#include <string_view>
#include <span>

#ifdef __OBJC__

#include <Cocoa/Cocoa.h>

// TODO: move it outside NSColor into a custom namespace instead

@interface NSColor (HexColorInterface)

// Returns a color in the genericRGBColorSpace colorspace with the specified 8bit integer components
+ (NSColor *)colorWithRGBA:(uint32_t)_rgba;

// Returns a color which is either a color produced from a hex code (e.g. #RRGGBBAA) or a system-defined color specified
// by @colorName
+ (NSColor *)colorWithHexString:(std::string_view)_hex;

// Return a list of the names of the system-defined colors. They can be interpretet by 'colorWithHexString'
+ (std::span<const std::string_view>)systemColorNames;

// Returns an 4*8bit integer representation of the color in the genericRGBColorSpace colorspace
- (uint32_t)toRGBA;

// Returns a hexadecimal or @-named description of the color
- (NSString *)toHexString;

// Returns a hexadecimal or @-named description of the color
- (std::string)toHexStdString;

@end

#endif
