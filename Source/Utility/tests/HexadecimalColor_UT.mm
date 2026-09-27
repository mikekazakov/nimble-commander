// Copyright (C) 2022-2026 Michael Kazakov. Subject to GNU General Public License version 3.
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
    for( const std::string_view &name : NSColor.systemColorNames ) {
        // we CAN'T verify a symmetric round-trip name-wise, but we CAN verify that a result is the same color
        NSColor *orig_color = [NSColor colorWithHexString:name];
        const auto hex = [orig_color toHexStdString]; // might be different than the 'name'
        auto restored_color = [NSColor colorWithHexString:hex];
        CHECK(orig_color == restored_color); // should be equal up to the pointer. works even for tagged pointers!
    }
}

TEST_CASE(PREFIX "System colors serialization, direct")
{
    NSAppearance *appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    [appearance performAsCurrentDrawingAppearance:^{
      // Current colors, 1:1 mapping
      struct CurrentTC {
          std::string_view str;
          NSColor *color;
      } const current_tcs[] = {
          {"@blackColor", NSColor.blackColor},
          {"@darkGrayColor", NSColor.darkGrayColor},
          {"@lightGrayColor", NSColor.lightGrayColor},
          {"@whiteColor", NSColor.whiteColor},
          {"@grayColor", NSColor.grayColor},
          {"@redColor", NSColor.redColor},
          {"@greenColor", NSColor.greenColor},
          {"@blueColor", NSColor.blueColor},
          {"@cyanColor", NSColor.cyanColor},
          {"@yellowColor", NSColor.yellowColor},
          {"@magentaColor", NSColor.magentaColor},
          {"@orangeColor", NSColor.orangeColor},
          {"@brownColor", NSColor.brownColor},
          {"@clearColor", NSColor.clearColor},
          {"@controlColor", NSColor.controlColor},
          {"@controlTextColor", NSColor.controlTextColor},
          {"@controlBackgroundColor", NSColor.controlBackgroundColor},
          {"@selectedControlColor", NSColor.selectedControlColor},
          {"@selectedControlTextColor", NSColor.selectedControlTextColor},
          {"@disabledControlTextColor", NSColor.disabledControlTextColor},
          {"@textColor", NSColor.textColor},
          {"@textBackgroundColor", NSColor.textBackgroundColor},
          {"@selectedTextColor", NSColor.selectedTextColor},
          {"@selectedTextBackgroundColor", NSColor.selectedTextBackgroundColor},
          {"@gridColor", NSColor.gridColor},
          {"@keyboardFocusIndicatorColor", NSColor.keyboardFocusIndicatorColor},
          {"@windowBackgroundColor", NSColor.windowBackgroundColor},
          {"@underPageBackgroundColor", NSColor.underPageBackgroundColor},
          {"@labelColor", NSColor.labelColor},
          {"@secondaryLabelColor", NSColor.secondaryLabelColor},
          {"@tertiaryLabelColor", NSColor.tertiaryLabelColor},
          {"@quaternaryLabelColor", NSColor.quaternaryLabelColor},
          {"@windowFrameTextColor", NSColor.windowFrameTextColor},
          {"@selectedMenuItemTextColor", NSColor.selectedMenuItemTextColor},
          {"@highlightColor", NSColor.highlightColor},
          {"@shadowColor", NSColor.shadowColor},
          {"@headerTextColor", NSColor.headerTextColor},
          {"@alternateSelectedControlTextColor", NSColor.alternateSelectedControlTextColor},
          {"@linkColor", NSColor.linkColor},
          {"@placeholderTextColor", NSColor.placeholderTextColor},
          {"@systemRedColor", NSColor.systemRedColor},
          {"@systemGreenColor", NSColor.systemGreenColor},
          {"@systemBlueColor", NSColor.systemBlueColor},
          {"@systemOrangeColor", NSColor.systemOrangeColor},
          {"@systemYellowColor", NSColor.systemYellowColor},
          {"@systemBrownColor", NSColor.systemBrownColor},
          {"@systemPinkColor", NSColor.systemPinkColor},
          {"@systemPurpleColor", NSColor.systemPurpleColor},
          {"@systemGrayColor", NSColor.systemGrayColor},
          {"@systemTealColor", NSColor.systemTealColor},
          {"@systemIndigoColor", NSColor.systemIndigoColor},
          {"@systemMintColor", NSColor.systemMintColor},
          {"@systemCyanColor", NSColor.systemCyanColor},
          {"@findHighlightColor", NSColor.findHighlightColor},
          {"@separatorColor", NSColor.separatorColor},
          {"@selectedContentBackgroundColor", NSColor.selectedContentBackgroundColor},
          {"@unemphasizedSelectedContentBackgroundColor", NSColor.unemphasizedSelectedContentBackgroundColor},
          // {"@alternatingContentBackgroundColors0", NSColor.alternatingContentBackgroundColors[0]},
          {"@alternatingContentBackgroundColors1", NSColor.alternatingContentBackgroundColors[1]},
          {"@unemphasizedSelectedTextBackgroundColor", NSColor.unemphasizedSelectedTextBackgroundColor},
          {"@unemphasizedSelectedTextColor", NSColor.unemphasizedSelectedTextColor},
          {"@controlAccentColor", NSColor.controlAccentColor},
      };
      for( const CurrentTC &tc : current_tcs ) {
          INFO(tc.str);
          CHECK([tc.color toHexStdString] == tc.str);             // serialization
          CHECK([NSColor colorWithHexString:tc.str] == tc.color); // deserialization
      }

      // Replaced colors, check only deserialization
      struct ReplacementTC {
          std::string_view str;
          NSColor *color;
      } const replacement_tcs[] = {
          {"@secondarySelectedControlColor", NSColor.unemphasizedSelectedContentBackgroundColor},
          {"@alternateSelectedControlColor", NSColor.selectedContentBackgroundColor},
          {"@controlAlternatingRowBackgroundColors0", NSColor.alternatingContentBackgroundColors[0]},
          {"@controlAlternatingRowBackgroundColors1", NSColor.alternatingContentBackgroundColors[1]},
      };
      for( const ReplacementTC &tc : replacement_tcs ) {
          INFO(tc.str);
          CHECK([NSColor colorWithHexString:tc.str] == tc.color); // deserialization
      }

      // Dropped colors, check only deserialization
      struct DroppedTC {
          std::string_view str;
          NSColor *color;
      } const dropped_tcs[] = {
          {"@controlShadowColor", NSColor.systemPinkColor},
          {"@controlDarkShadowColor", NSColor.systemPinkColor},
          {"@controlHighlightColor", NSColor.systemPinkColor},
          {"@controlLightHighlightColor", NSColor.systemPinkColor},
          {"@scrollBarColor", NSColor.systemPinkColor},
          {"@knobColor", NSColor.systemPinkColor},
          {"@selectedKnobColor", NSColor.systemPinkColor},
          {"@windowFrameColor", NSColor.systemPinkColor},
          {"@selectedMenuItemColor", NSColor.systemPinkColor},
          {"@headerColor", NSColor.systemPinkColor},
      };
      for( const DroppedTC &tc : dropped_tcs ) {
          INFO(tc.str);
          CHECK([NSColor colorWithHexString:tc.str] == tc.color); // deserialization
      }
    }];
}

#undef PREFIX
