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
          {.str = "@blackColor", .color = NSColor.blackColor},
          {.str = "@darkGrayColor", .color = NSColor.darkGrayColor},
          {.str = "@lightGrayColor", .color = NSColor.lightGrayColor},
          {.str = "@whiteColor", .color = NSColor.whiteColor},
          {.str = "@grayColor", .color = NSColor.grayColor},
          {.str = "@redColor", .color = NSColor.redColor},
          {.str = "@greenColor", .color = NSColor.greenColor},
          {.str = "@blueColor", .color = NSColor.blueColor},
          {.str = "@cyanColor", .color = NSColor.cyanColor},
          {.str = "@yellowColor", .color = NSColor.yellowColor},
          {.str = "@magentaColor", .color = NSColor.magentaColor},
          {.str = "@orangeColor", .color = NSColor.orangeColor},
          {.str = "@brownColor", .color = NSColor.brownColor},
          {.str = "@clearColor", .color = NSColor.clearColor},
          {.str = "@controlColor", .color = NSColor.controlColor},
          {.str = "@controlTextColor", .color = NSColor.controlTextColor},
          {.str = "@controlBackgroundColor", .color = NSColor.controlBackgroundColor},
          {.str = "@selectedControlColor", .color = NSColor.selectedControlColor},
          {.str = "@selectedControlTextColor", .color = NSColor.selectedControlTextColor},
          {.str = "@disabledControlTextColor", .color = NSColor.disabledControlTextColor},
          {.str = "@textColor", .color = NSColor.textColor},
          {.str = "@textBackgroundColor", .color = NSColor.textBackgroundColor},
          {.str = "@selectedTextColor", .color = NSColor.selectedTextColor},
          {.str = "@selectedTextBackgroundColor", .color = NSColor.selectedTextBackgroundColor},
          {.str = "@gridColor", .color = NSColor.gridColor},
          {.str = "@keyboardFocusIndicatorColor", .color = NSColor.keyboardFocusIndicatorColor},
          {.str = "@windowBackgroundColor", .color = NSColor.windowBackgroundColor},
          {.str = "@underPageBackgroundColor", .color = NSColor.underPageBackgroundColor},
          {.str = "@labelColor", .color = NSColor.labelColor},
          {.str = "@secondaryLabelColor", .color = NSColor.secondaryLabelColor},
          {.str = "@tertiaryLabelColor", .color = NSColor.tertiaryLabelColor},
          {.str = "@quaternaryLabelColor", .color = NSColor.quaternaryLabelColor},
          {.str = "@windowFrameTextColor", .color = NSColor.windowFrameTextColor},
          {.str = "@selectedMenuItemTextColor", .color = NSColor.selectedMenuItemTextColor},
          {.str = "@highlightColor", .color = NSColor.highlightColor},
          {.str = "@shadowColor", .color = NSColor.shadowColor},
          {.str = "@headerTextColor", .color = NSColor.headerTextColor},
          {.str = "@alternateSelectedControlTextColor", .color = NSColor.alternateSelectedControlTextColor},
          {.str = "@linkColor", .color = NSColor.linkColor},
          {.str = "@placeholderTextColor", .color = NSColor.placeholderTextColor},
          {.str = "@systemRedColor", .color = NSColor.systemRedColor},
          {.str = "@systemGreenColor", .color = NSColor.systemGreenColor},
          {.str = "@systemBlueColor", .color = NSColor.systemBlueColor},
          {.str = "@systemOrangeColor", .color = NSColor.systemOrangeColor},
          {.str = "@systemYellowColor", .color = NSColor.systemYellowColor},
          {.str = "@systemBrownColor", .color = NSColor.systemBrownColor},
          {.str = "@systemPinkColor", .color = NSColor.systemPinkColor},
          {.str = "@systemPurpleColor", .color = NSColor.systemPurpleColor},
          {.str = "@systemGrayColor", .color = NSColor.systemGrayColor},
          {.str = "@systemTealColor", .color = NSColor.systemTealColor},
          {.str = "@systemIndigoColor", .color = NSColor.systemIndigoColor},
          {.str = "@systemMintColor", .color = NSColor.systemMintColor},
          {.str = "@systemCyanColor", .color = NSColor.systemCyanColor},
          {.str = "@findHighlightColor", .color = NSColor.findHighlightColor},
          {.str = "@separatorColor", .color = NSColor.separatorColor},
          {.str = "@selectedContentBackgroundColor", .color = NSColor.selectedContentBackgroundColor},
          {.str = "@unemphasizedSelectedContentBackgroundColor",
           .color = NSColor.unemphasizedSelectedContentBackgroundColor},
          // {.str = "@alternatingContentBackgroundColors0", .color = NSColor.alternatingContentBackgroundColors[0]},
          {.str = "@alternatingContentBackgroundColors1", .color = NSColor.alternatingContentBackgroundColors[1]},
          {.str = "@unemphasizedSelectedTextBackgroundColor", .color = NSColor.unemphasizedSelectedTextBackgroundColor},
          {.str = "@unemphasizedSelectedTextColor", .color = NSColor.unemphasizedSelectedTextColor},
          {.str = "@controlAccentColor", .color = NSColor.controlAccentColor},
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
          {.str = "@secondarySelectedControlColor", .color = NSColor.unemphasizedSelectedContentBackgroundColor},
          {.str = "@alternateSelectedControlColor", .color = NSColor.selectedContentBackgroundColor},
          {.str = "@controlAlternatingRowBackgroundColors0", .color = NSColor.alternatingContentBackgroundColors[0]},
          {.str = "@controlAlternatingRowBackgroundColors1", .color = NSColor.alternatingContentBackgroundColors[1]},
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
          {.str = "@controlShadowColor", .color = NSColor.systemPinkColor},
          {.str = "@controlDarkShadowColor", .color = NSColor.systemPinkColor},
          {.str = "@controlHighlightColor", .color = NSColor.systemPinkColor},
          {.str = "@controlLightHighlightColor", .color = NSColor.systemPinkColor},
          {.str = "@scrollBarColor", .color = NSColor.systemPinkColor},
          {.str = "@knobColor", .color = NSColor.systemPinkColor},
          {.str = "@selectedKnobColor", .color = NSColor.systemPinkColor},
          {.str = "@windowFrameColor", .color = NSColor.systemPinkColor},
          {.str = "@selectedMenuItemColor", .color = NSColor.systemPinkColor},
          {.str = "@headerColor", .color = NSColor.systemPinkColor},
      };
      for( const DroppedTC &tc : dropped_tcs ) {
          INFO(tc.str);
          CHECK([NSColor colorWithHexString:tc.str] == tc.color); // deserialization
      }
    }];
}

#undef PREFIX
