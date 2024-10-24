// Copyright (C) 2015-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/UnorderedUtil.h>
#include <Utility/HexadecimalColor.h>
#include <Utility/SystemInformation.h>
#include <algorithm>
#include <vector>

// In some contexts, primarily OpenGL, the term "RGBA" actually means the colors are stored in
// memory such that R is at the lowest address, G after it, B after that, and A last. This is not
// the format described above. OpenGL describes the above format as "BGRA" on a little-endian
// machine and "ARGB" on a big-endian machine.

// RGBA format:
// RRRRRRRRGGGGGGGGBBBBBBBBAAAAAAAA
static constexpr uint32_t MakeRGBA(uint8_t _r, uint8_t _g, uint8_t _b, uint8_t _a) noexcept
{
    return uint32_t(_r) | (uint32_t(_g) << 8) | (uint32_t(_b) << 16) | (uint32_t(_a) << 24);
}

static constexpr auto g_BlackColor = MakeRGBA(0, 0, 0, 255);

static constexpr int HexToInt(char _c) noexcept
{
    if( _c >= 48 && _c <= 57 )
        return _c - 48; // 0..9
    if( _c >= 65 && _c <= 70 )
        return _c - 65 + 10; // A..F
    if( _c >= 97 && _c <= 102 )
        return _c - 97 + 10; // a..F
    return 0;
}

static constexpr int DupHex(int _h) noexcept
{
    return (_h * 16) + _h;
}

static constexpr uint32_t HexadecimalColorStringToRGBA(std::string_view _string) noexcept
{
    if( _string.length() < 4 || _string[0] != '#' )
        return g_BlackColor;

    if( _string.length() >= 9 ) // #RRGGBBAA
        return MakeRGBA(static_cast<uint8_t>((HexToInt(_string[1]) * 16) + HexToInt(_string[2])),
                        static_cast<uint8_t>((HexToInt(_string[3]) * 16) + HexToInt(_string[4])),
                        static_cast<uint8_t>((HexToInt(_string[5]) * 16) + HexToInt(_string[6])),
                        static_cast<uint8_t>((HexToInt(_string[7]) * 16) + HexToInt(_string[8])));
    if( _string.length() >= 7 ) // #RRGGBB
        return MakeRGBA(static_cast<uint8_t>((HexToInt(_string[1]) * 16) + HexToInt(_string[2])),
                        static_cast<uint8_t>((HexToInt(_string[3]) * 16) + HexToInt(_string[4])),
                        static_cast<uint8_t>((HexToInt(_string[5]) * 16) + HexToInt(_string[6])),
                        255);
    if( _string.length() >= 5 ) // #RGBA
        return MakeRGBA(static_cast<uint8_t>(DupHex(HexToInt(_string[1]))),
                        static_cast<uint8_t>(DupHex(HexToInt(_string[2]))),
                        static_cast<uint8_t>(DupHex(HexToInt(_string[3]))),
                        static_cast<uint8_t>(DupHex(HexToInt(_string[4]))));
    if( _string.length() >= 4 ) // #RGB
        return MakeRGBA(static_cast<uint8_t>(DupHex(HexToInt(_string[1]))),
                        static_cast<uint8_t>(DupHex(HexToInt(_string[2]))),
                        static_cast<uint8_t>(DupHex(HexToInt(_string[3]))),
                        255);

    return g_BlackColor;
}

static constexpr void HexadecimalColorRGBAToString(uint32_t _rgba, char _string[10]) noexcept
{
    constexpr char hex[] = "0123456789ABCDEF";
    const uint8_t r = uint8_t(_rgba & 0x000000FF);
    const uint8_t g = uint8_t((_rgba >> 8) & 0x000000FF);
    const uint8_t b = uint8_t((_rgba >> 16) & 0x000000FF);
    const uint8_t a = uint8_t((_rgba >> 24) & 0x000000FF);

    _string[0] = '#';
    _string[1] = hex[r >> 4];
    _string[2] = hex[r & 0xF];
    _string[3] = hex[g >> 4];
    _string[4] = hex[g & 0xF];
    _string[5] = hex[b >> 4];
    _string[6] = hex[b & 0xF];
    if( a != 255 ) {
        _string[7] = hex[a >> 4];
        _string[8] = hex[a & 0xF];
        _string[9] = 0;
    }
    else {
        _string[7] = 0;
    }
}

// TODO: unit test for a round-trip!

[[clang::no_destroy]]                                                   //
static const ankerl::unordered_dense::map<std::string,                  //
                                          NSColor *,                    //
                                          nc::UnorderedStringHashEqual, //
                                          nc::UnorderedStringHashEqual> //
    g_SystemColors = {
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
        {"@controlShadowColor", NSColor.controlShadowColor},
        {"@controlDarkShadowColor", NSColor.controlDarkShadowColor},
        {"@controlColor", NSColor.controlColor},
        {"@controlHighlightColor", NSColor.controlHighlightColor},
        {"@controlLightHighlightColor", NSColor.controlLightHighlightColor},
        {"@controlTextColor", NSColor.controlTextColor},
        {"@controlBackgroundColor", NSColor.controlBackgroundColor},
        {"@selectedControlColor", NSColor.selectedControlColor},
        {"@secondarySelectedControlColor", NSColor.secondarySelectedControlColor},
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
        {"@scrollBarColor", NSColor.scrollBarColor},
        {"@knobColor", NSColor.knobColor},
        {"@selectedKnobColor", NSColor.selectedKnobColor},
        {"@windowFrameColor", NSColor.windowFrameColor},
        {"@windowFrameTextColor", NSColor.windowFrameTextColor},
        {"@selectedMenuItemColor", NSColor.selectedMenuItemColor},
        {"@selectedMenuItemTextColor", NSColor.selectedMenuItemTextColor},
        {"@highlightColor", NSColor.highlightColor},
        {"@shadowColor", NSColor.shadowColor},
        {"@headerColor", NSColor.headerColor},
        {"@headerTextColor", NSColor.headerTextColor},
        {"@alternateSelectedControlColor", NSColor.alternateSelectedControlColor},
        {"@alternateSelectedControlTextColor", NSColor.alternateSelectedControlTextColor},
        {"@controlAlternatingRowBackgroundColors0", NSColor.controlAlternatingRowBackgroundColors[0]},
        {"@controlAlternatingRowBackgroundColors1", NSColor.controlAlternatingRowBackgroundColors[1]},
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
        {"@findHighlightColor", NSColor.findHighlightColor},
        {"@separatorColor", NSColor.separatorColor},
        {"@selectedContentBackgroundColor", NSColor.selectedContentBackgroundColor},
        {"@unemphasizedSelectedContentBackgroundColor", NSColor.unemphasizedSelectedContentBackgroundColor},
        {"@alternatingContentBackgroundColors0", NSColor.alternatingContentBackgroundColors[0]},
        {"@alternatingContentBackgroundColors1", NSColor.alternatingContentBackgroundColors[1]},
        {"@unemphasizedSelectedTextBackgroundColor", NSColor.unemphasizedSelectedTextBackgroundColor},
        {"@unemphasizedSelectedTextColor", NSColor.unemphasizedSelectedTextColor},
        {"@controlAccentColor", NSColor.controlAccentColor},
};

static NSColor *DecodeSystemColor(std::string_view _color) noexcept
{
    if( _color.empty() || _color.front() != '@' )
        return nil;

    auto it = g_SystemColors.find(_color);
    if( it != g_SystemColors.end() )
        return it->second;
    return nil;
}

// O(1) complexity.
// Returns an empty string view if a corresponding color was not found.
static std::string_view FindCorrespondingSystemColorNameViaPtr(NSColor *_for_color) noexcept
{
    using Map = ankerl::unordered_dense::map<void *, std::string_view>;
    [[clang::no_destroy]] static const Map ptrs_to_original_names = [] {
        Map map;
        map.reserve(g_SystemColors.size());
        for( auto &kv : g_SystemColors )
            map.emplace((__bridge void *)kv.second, std::string_view(kv.first));
        return map;
    }();
    const auto it = ptrs_to_original_names.find((__bridge void *)_for_color);
    if( it != ptrs_to_original_names.end() )
        return it->second;
    else
        return {};
}

// O(1) complexity, but requires producing of a color description.
// Returns an empty string view if a corresponding color was not found.
static std::string_view FindCorrespondingSystemColorNameViaDescription(NSColor *_for_color) noexcept
{
    using Map = ankerl::unordered_dense::
        map<std::string, std::string_view, nc::UnorderedStringHashEqual, nc::UnorderedStringHashEqual>;
    [[clang::no_destroy]] static const Map description_to_original_names = [] {
        Map map;
        map.reserve(g_SystemColors.size());
        for( auto &kv : g_SystemColors )
            map.emplace(std::string(kv.second.description.UTF8String), std::string_view(kv.first));
        return map;
    }();

    if( _for_color == nil )
        return {};

    const auto description = _for_color.description;
    const auto it = description_to_original_names.find(description.UTF8String);
    if( it != description_to_original_names.end() )
        return it->second;
    else
        return {};
}

static bool IsNamed(NSColor *_color) noexcept
{
    return _color.type == NSColorTypeCatalog;
}

static std::span<const std::string_view> SystemColorNames() noexcept
{
    static const auto names = [] {
        [[clang::no_destroy]] static std::vector<std::string_view> v;
        v.reserve(g_SystemColors.size());
        for( const auto &kv : g_SystemColors )
            v.push_back(kv.first);
        std::ranges::sort(v);
        return std::span<const std::string_view>(v);
    }();
    return names;
}

@implementation NSColor (HexColorInterface)

+ (NSColor *)colorWithRGBA:(uint32_t)_rgba
{
    return [NSColor colorWithCalibratedRed:double(_rgba & 0x000000FF) / 255.
                                     green:double((_rgba >> 8) & 0x000000FF) / 255.
                                      blue:double((_rgba >> 16) & 0x000000FF) / 255.
                                     alpha:double((_rgba >> 24) & 0x000000FF) / 255.];
}

+ (NSColor *)colorWithHexString:(std::string_view)_hex
{
    if( _hex.empty() )
        return NSColor.blackColor;

    if( auto sc = DecodeSystemColor(_hex) )
        return sc;
    else
        return [NSColor colorWithRGBA:HexadecimalColorStringToRGBA(_hex)];
}

- (uint32_t)toRGBA
{
    double r;
    double g;
    double b;
    double a;
    if( !IsNamed(self) && self.colorSpace == NSColorSpace.genericRGBColorSpace )
        [self getRed:&r green:&g blue:&b alpha:&a];
    else
        [[self colorUsingColorSpace:NSColorSpace.genericRGBColorSpace] getRed:&r green:&g blue:&b alpha:&a];

    return MakeRGBA(static_cast<uint8_t>(std::min(1.0, std::max(0.0, r)) * 255.),
                    static_cast<uint8_t>(std::min(1.0, std::max(0.0, g)) * 255.),
                    static_cast<uint8_t>(std::min(1.0, std::max(0.0, b)) * 255.),
                    static_cast<uint8_t>(std::min(1.0, std::max(0.0, a)) * 255.));
}

- (NSString *)toHexString
{
    const auto hex = [self toHexStdString];
    return [NSString stringWithUTF8String:hex.c_str()];
}

- (std::string)toHexStdString
{
    // 1st - try to find a system color via exact pointer match
    if( auto name = FindCorrespondingSystemColorNameViaPtr(self); !name.empty() )
        return std::string(name);

    // 2nd - try to find a system color via exact same description
    if( auto name = FindCorrespondingSystemColorNameViaDescription(self); !name.empty() )
        return std::string(name);

    // 3rd - otherwise produce a generic hex string
    char buf[16];
    HexadecimalColorRGBAToString([self toRGBA], buf);
    return buf;
}

+ (std::span<const std::string_view>)systemColorNames
{
    return SystemColorNames();
}

@end
