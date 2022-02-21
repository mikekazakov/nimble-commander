// Copyright (C) 2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UnitTests_main.h"
#include "HexadecimalColor.h"
#include "StringExtras.h"

#define PREFIX "HexadecimalColor "

TEST_CASE(PREFIX "[NSColor toRGBA]")
{
    CHECK([[NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:1.] toRGBA] == 0xFF000000);
    CHECK([[NSColor colorWithCalibratedRed:1. green:1. blue:1. alpha:1.] toRGBA] == 0xFFFFFFFF);
    CHECK([[NSColor colorWithCalibratedRed:1. green:0. blue:0. alpha:1.] toRGBA] == 0xFF0000FF);
    CHECK([[NSColor colorWithCalibratedRed:0. green:1. blue:0. alpha:1.] toRGBA] == 0xFF00FF00);
    CHECK([[NSColor colorWithCalibratedRed:0. green:0. blue:1. alpha:1.] toRGBA] == 0xFFFF0000);
    CHECK([[NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:0.5] toRGBA] == 0x7f000000);
}

TEST_CASE(PREFIX "[NSColor colorWithRGBA:(uint32_t)_rgba]")
{
    CHECK([[NSColor colorWithRGBA:0xFF000000] toRGBA] == 0xFF000000);
    CHECK([[NSColor colorWithRGBA:0xFFFFFFFF] toRGBA] == 0xFFFFFFFF);
    CHECK([[NSColor colorWithRGBA:0xFF0000FF] toRGBA] == 0xFF0000FF);
    CHECK([[NSColor colorWithRGBA:0xFF00FF00] toRGBA] == 0xFF00FF00);
    CHECK([[NSColor colorWithRGBA:0xFFFF0000] toRGBA] == 0xFFFF0000);
    CHECK([[NSColor colorWithRGBA:0x7f000000] toRGBA] == 0x7f000000);
}

TEST_CASE(PREFIX "[NSColor colorWithHexString:(std::string_view)_hex]")
{
    CHECK([[NSColor colorWithHexString:{}] toRGBA] == 0xFF000000);
    CHECK([[NSColor colorWithHexString:""] toRGBA] == 0xFF000000);
    CHECK([[NSColor colorWithHexString:"blah"] toRGBA] == 0xFF000000);
    CHECK([[NSColor colorWithHexString:"#000"] toRGBA] == 0xFF000000);
    CHECK([[NSColor colorWithHexString:"#FFF"] toRGBA] == 0xFFFFFFFF);
    CHECK([[NSColor colorWithHexString:"#F00"] toRGBA] == 0xFF0000FF);
    CHECK([[NSColor colorWithHexString:"#0F0"] toRGBA] == 0xFF00FF00);
    CHECK([[NSColor colorWithHexString:"#00F"] toRGBA] == 0xFFFF0000);
    CHECK([[NSColor colorWithHexString:"#0000"] toRGBA] == 0x00000000);
    CHECK([[NSColor colorWithHexString:"#FFFF"] toRGBA] == 0xFFFFFFFF);
    CHECK([[NSColor colorWithHexString:"#FA57"] toRGBA] == 0x7755AAFF);
    CHECK([[NSColor colorWithHexString:"#012345"] toRGBA] == 0xFF452301);
    CHECK([[NSColor colorWithHexString:"#67890A"] toRGBA] == 0xFF0A8967);
    CHECK([[NSColor colorWithHexString:"#ABCDEF"] toRGBA] == 0xFFEFCDAB);
    CHECK([[NSColor colorWithHexString:"#01234567"] toRGBA] == 0x67452301);
    CHECK([[NSColor colorWithHexString:"#890ABCDE"] toRGBA] == 0xDEBC0A89);
    CHECK([NSColor colorWithHexString:"#890ABCDE"].colorSpace == NSColorSpace.genericRGBColorSpace);
}

TEST_CASE(PREFIX "System colors can be deserialized and serialized")
{
    for( auto name : NSColor.systemColorNames ) {
        // we CAN'T verify a symmetric round-trip name-wise, but we CAN verify that a result is the same color
        auto orig_color = [NSColor colorWithHexString:name];
        auto hex = [orig_color toHexStdString]; // might be different than the 'name'
        auto restored_color = [NSColor colorWithHexString:hex];
        CHECK(orig_color == restored_color); // should be equal up to the pointer. works even for tagged pointers!
    }
}
