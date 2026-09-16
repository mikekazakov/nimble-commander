// Copyright (C) 2023-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <ExtendedCharRegistry.h>
#include "Tests.h"

#define PREFIX "nc::term::ExtendedCharRegistry "

namespace ExtendedCharRegistryTest {

using namespace nc;
using namespace nc::term;
using namespace std::string_literals;

using Reg = ExtendedCharRegistry;
using AR = ExtendedCharRegistry::AppendResult;

static bool is(const base::CFPtr<CFStringRef> &_what, std::u16string_view _exp)
{
    if( !_what )
        return false;

    const auto len = CFStringGetLength(_what.get());
    if( auto ptr = CFStringGetCharactersPtr(_what.get()); ptr != nullptr ) {
        return std::u16string_view(reinterpret_cast<const char16_t *>(ptr), len) == _exp;
    }
    else {
        std::u16string str;
        str.resize(len);
        CFStringGetCharacters(_what.get(), CFRangeMake(0, len), reinterpret_cast<UniChar *>(str.data()));
        return str == _exp;
    }
}

static std::string to_utf8(std::u16string_view _str)
{
    if( _str.empty() )
        return {};
    const auto cf_str = base::CFPtr<CFStringRef>::adopt(
        CFStringCreateWithCharacters(nullptr, reinterpret_cast<const uint16_t *>(_str.data()), _str.length()));

    char buf[1024]; // whatever...
    long characters_used = 0;
    CFStringGetBytes(cf_str.get(),
                     CFRangeMake(0, CFStringGetLength(cf_str.get())),
                     kCFStringEncodingUTF8,
                     0,
                     false,
                     reinterpret_cast<UInt8 *>(buf),
                     sizeof(buf),
                     &characters_used);
    buf[characters_used] = 0;
    return buf;
}

TEST_CASE(PREFIX "Append from scratch")
{
    ExtendedCharRegistry r;

    // trivial
    CHECK(r.Append(u"") == AR{});
    CHECK(r.Append(u"a") == AR{U'a', 1});
    CHECK(r.Append(u"aa") == AR{U'a', 1});
    CHECK(r.Append(u"a😹") == AR{U'a', 1});
    CHECK(r.Append(u"aaaaaaaaaaaa") == AR{U'a', 1});
    CHECK(r.Append(u"привет!") == AR{U'п', 1});
    CHECK(r.Append(u"❆") == AR{U'❆', 1});
    CHECK(r.Append(u"❆a") == AR{U'❆', 1});
    CHECK(r.Append(u"😹") == AR{U'😹', 2});  // D83D DE39
    CHECK(r.Append(u"😹a") == AR{U'😹', 2}); // D83D DE39
    CHECK(r.Append(u"💩") == AR{U'💩', 2});  // D83D DCA9

    // emoji
    {
        // 🧜 D83E DDDC, 🏾 D83C DFFE, ZWJ 200D, ♀️2640, VS FE0F
        auto ar = r.Append(u"🧜🏾‍♀️");
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(ar.eaten == 7);
        CHECK(is(r.Decode(ar.newchar), u"🧜🏾‍♀️"));

        // clang-format off
        CHECK(r.Append(u"🧜🏾‍♀️") == ar);
        CHECK(r.Append(u"🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️🧜🏾‍♀️") == ar);
        // clang-format on
    }

    // emoji
    {
        // 👩 D83D DC69, 🏼 D83C DFFC,  ZWJ 200D, 🏫 D83C DFEB
        auto ar = r.Append(u"👩🏼‍🏫");
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(ar.eaten == 7);
        CHECK(is(r.Decode(ar.newchar), u"👩🏼‍🏫"));

        // clang-format off
        CHECK(r.Append(u"👩🏼‍🏫") == ar);
        CHECK(r.Append(u"👩🏼‍🏫👩🏼‍🏫👩🏼‍🏫👩🏼‍🏫👩🏼‍🏫👩🏼‍🏫👩🏼‍🏫") == ar);
        // clang-format on
    }

    // emoji
    {
        // 👩 D83D DC69, 🏿 D83C DFFF, ZWJ 200D, ❤️ 2764 FE0F, ZWJ 200D, 👩 D83D DC69, 🏼 D83C DFFC
        auto ar = r.Append(u"👩🏿‍❤️‍👩🏼");
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(ar.eaten == 12);
        CHECK(is(r.Decode(ar.newchar), u"👩🏿‍❤️‍👩🏼"));

        // clang-format off
        CHECK(r.Append(u"👩🏿‍❤️‍👩🏼") == ar);
        CHECK(r.Append(u"👩🏿‍❤️‍👩🏼👩🏿‍❤️‍👩🏼👩🏿‍❤️‍👩🏼👩🏿‍❤️‍👩🏼👩🏿‍❤️‍👩👩🏿‍❤️‍👩🏼") == ar);
        CHECK(r.Append(u"👩🏿‍❤️‍👩🏼a") == ar);
        // clang-format on
    }

    // combining characters
    {
        auto ar = r.Append(u"е\x0308"); // е 0435, ◌̈ 0308
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(ar.eaten == 2);

        CHECK(r.Append(u"е\x0308\x0435\x0308") == ar);
        CHECK(r.Append(u"е\x0308\x0061") == ar); // a 0061
        CHECK(r.Append(u"е\x0308😹") == ar);
    }

    // flags
    {
        auto ar = r.Append(u"🇬🇧"); // 🇬🇧 D83C DDEC D83C DDE7
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"🇬🇧"));
        CHECK(ar.eaten == 4);

        CHECK(r.Append(u"🇬🇧🇬🇧🇬🇧🇬🇧") == ar);
        CHECK(r.Append(u"🇬🇧🧜🏾‍♀️") == ar);
        CHECK(r.Append(u"🇬🇧a") == ar);
        CHECK(r.Append(u"🇬🇧😹") == ar);
    }
}

TEST_CASE(PREFIX "Append to a base character")
{
    ExtendedCharRegistry r;

    // trivial
    {
        CHECK(r.Append(u"b", U'a') == AR{'a', 0});
        CHECK(r.Append(u"🧜", U'a') == AR{'a', 0});
        CHECK(r.Append(u" ", U'a') == AR{'a', 0});
        CHECK(r.Append(u"a", U'🇬') == AR{U'🇬', 0});
    }

    // 🧜🏾‍♀️ = 🧜 D83E DDDC, 🏾 D83C DFFE, ZWJ 200D, ♀️2640, VS FE0F
    {
        auto ar = r.Append(u"\xD83C\xDFFE", U'🧜');
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"🧜🏾"));
        CHECK(ar.eaten == 2);

        CHECK(r.Append(u"\xD83C\xDFFE", U'🧜') == ar);
    }
    {
        const auto ar = r.Append(u"\xD83C\xDFFE\x200D", U'🧜');
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"🧜🏾\x200D"));
        CHECK(ar.eaten == 3);
    }
    {
        const auto ar = r.Append(u"\xD83C\xDFFE\x200D", U'🧜');
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"🧜🏾\x200D"));
        CHECK(ar.eaten == 3);
    }
    {
        const auto ar = r.Append(u"\xD83C\xDFFE\x200D\x2640", U'🧜');
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"🧜🏾\x200D\x2640"));
        CHECK(ar.eaten == 4);
    }
    {
        const auto ar = r.Append(u"\xD83C\xDFFE\x200D\x2640\xFE0F", U'🧜');
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"🧜🏾\x200D\x2640\xFE0F"));
        CHECK(ar.eaten == 5);
    }

    // combining characters
    {
        const auto ar = r.Append(u"\x0308", 'e'); // е, ◌̈
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"e\x0308"));
        CHECK(ar.eaten == 1);
    }
    {
        const auto ar = r.Append(u"\x0300\x0301\x0302\x0303\x0304\x0304\x0305\x0306\x0307\x0308", 'e');
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"e\x0300\x0301\x0302\x0303\x0304\x0304\x0305\x0306\x0307\x0308"));
        CHECK(ar.eaten == 10);
    }
    {
        const auto ar = r.Append(u"\x0335\x0356\x034d\x030a", 'Z');
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"Z\x0335\x0356\x034d\x030a"));
        CHECK(ar.eaten == 4);
    }

    // flags
    {
        const auto ar = r.Append(u"🇧", U'🇬');
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"🇬🇧"));
        CHECK(ar.eaten == 2);
    }
    {
        const auto ar = r.Append(u"🇱", U'🇬');
        CHECK(Reg::IsExtended(ar.newchar));
        CHECK(is(r.Decode(ar.newchar), u"🇬🇱"));
        CHECK(ar.eaten == 2);
    }
}

TEST_CASE(PREFIX "Append to an extended character")
{
    ExtendedCharRegistry r;

    {
        const char32_t invalid = static_cast<char32_t>((uint32_t(1) << 31) + 43634);
        const auto ar = r.Append(u"\x200D", invalid);
        CHECK(ar.newchar == invalid);
        CHECK(ar.eaten == 0);
    }

    // 🧜🏾‍♀️ = 🧜 D83E DDDC, 🏾 D83C DFFE, ZWJ 200D, ♀️2640, VS FE0F
    {
        const auto ar1 = r.Append(u"🧜🏾");
        auto ar2 = r.Append(u"\x200D\x2640\xFE0F", ar1.newchar);

        CHECK(Reg::IsExtended(ar2.newchar));
        CHECK(is(r.Decode(ar2.newchar), u"🧜🏾‍♀️"));
        CHECK(ar2.eaten == 3);

        auto ar3 = r.Append(u"\x200D\x2640\xFE0F!Hello, World!", ar1.newchar);
        CHECK(ar3 == ar2);
    }

    {
        const auto ar1 = r.Append(u"🧜🏾");
        const auto ar2 = r.Append(u"A", ar1.newchar);
        CHECK(ar2.newchar == ar1.newchar);
        CHECK(ar2.eaten == 0);
    }
}

TEST_CASE(PREFIX "IsDoubleWidth")
{
    ExtendedCharRegistry r;
    const auto dw = [&](std::u16string_view str) { return r.IsDoubleWidth(r.Append(str).newchar); };

    // clang-format off
    struct TC {
        std::u16string_view str;
        bool exp;
    } const cases[] = {
        {.str=u"a", .exp=false},
        {.str=u"❆", .exp=false},
        {.str=u"☁", .exp=false},
        {.str=u"☀", .exp=false},             // ☀ 2600
        {.str=u"☀\xfe0e", .exp=false},       // ☀ 2600 fe0e
        {.str=u"☀\xfe0e\xfe0f", .exp=false}, // ☀ 2600 fe0e fe0f
        {.str=u"☀\xfe0f", .exp=true},        // ☀️ 2600 fe0f
        {.str=u"☀\xfe0f\xfe0e", .exp=true},  // ☀️ 2600 fe0f fe0e
        {.str=u"🌦️", .exp=true},             // 🌦️ d83c df26
        {.str=u"🌦️", .exp=true},             // 🌦️ d83c df26
        {.str=u"⚡", .exp=true},             // ⚡ 26a1
        {.str=u"😹", .exp=true},             // 😹 D83D DE39
        {.str=u"🦄", .exp=true},             // 🦄 d83e dd84
        {.str=u"🧜🏾‍♀️", .exp=true},             // 🧜🏾‍♀️ d83e dddc d83c dffe 200d 2640 fe0f
        {.str=u"🇬🇧", .exp=true},             // 🇬🇧 d83c ddec d83c dde7
        {.str=u"👩🏿‍❤️‍👩🏼", .exp=true},             // 👩🏿‍❤️‍👩🏼 ud83d dc69 d83c dfff 200d 2764 fe0f 200d d83d dc69 d83c dffc
        {.str=u"⏏", .exp=false},             // ⏏ 23cf
        {.str=u"⏏\xfe0f", .exp=true},        // ⏏️ 23cf fe0f
        {.str=u"Ｍ", .exp=true},             // Ｍ ff2d
        {.str=u"ね", .exp=true},             // ね 306d
        {.str=u"е\x0308", .exp=false},       // е◌̈ 0435 0308
        {.str=u"Ｅ́", .exp=true},             // Ｅ́ ff25 0301
        {.str=u"𐅐", .exp=false},             // 𐅐 d800 dd50
        {.str=u"🏾", .exp=true},             // 🏾 feff d83c dffe
    };
    // clang-format on
    for( const auto tc : cases ) {
        INFO(to_utf8(tc.str));
        CHECK(dw(tc.str) == tc.exp);
    }
}

} // namespace ExtendedCharRegistryTest

#undef PREFIX
