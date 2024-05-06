// Copyright (C) 2018-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#define CATCH_CONFIG_ENABLE_BENCHMARKING
#include "UnitTests_main.h"
#include "FontExtras.h"
#include <Base/CFString.h>
#include <random>

// NB! disable by default, include in the UtilityUT to enable

using nc::utility::FontGeometryInfo;

[[clang::no_destroy]] static const auto g_RandomAlphabet = [] {
    std::vector<char> chars;
    for( char i = 'a'; i <= 'z'; ++i )
        chars.emplace_back(i);
    for( char i = 'A'; i <= 'Z'; ++i )
        chars.emplace_back(i);
    for( char i = '0'; i <= '9'; ++i )
        chars.emplace_back(i);
    return chars;
}();

static std::mt19937 g_RndGen(std::random_device{}());

static CFStringRef MakeRandomString(int _length)
{
    std::uniform_int_distribution<int> distribution(0, static_cast<int>(g_RandomAlphabet.size() - 1));
    std::string str;
    str.reserve(_length);
    while( _length-- > 0 )
        str.push_back(g_RandomAlphabet[distribution(g_RndGen)]);
    return CFStringCreateWithUTF8StdString(str);
}

static std::vector<CFStringRef> MakeRandomStrings(int _amount, int _length)
{
    std::vector<CFStringRef> strings(_amount, nullptr);
    for( auto &str : strings )
        str = MakeRandomString(_length);
    return strings;
}

static void Free(const std::vector<CFStringRef> &_strings)
{
    for( auto &string : _strings )
        CFRelease(string);
}

TEST_CASE("FontGeometryInfo::CalculateStringsWidths perf test", "[!benchmark]")
{
    const auto font = [NSFont systemFontOfSize:12.0];
    const auto length = 30;

    {
        const auto strings = MakeRandomStrings(100, length);
        BENCHMARK("100 strings")
        {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        };
        Free(strings);
    }
    {
        const auto strings = MakeRandomStrings(200, length);
        BENCHMARK("200 strings")
        {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        };
        Free(strings);
    }
    {
        const auto strings = MakeRandomStrings(300, length);
        BENCHMARK("300 strings")
        {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        };
        Free(strings);
    }
    {
        const auto strings = MakeRandomStrings(400, length);
        BENCHMARK("400 strings")
        {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        };
        Free(strings);
    }
    {
        const auto strings = MakeRandomStrings(500, length);
        BENCHMARK("500 strings")
        {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        };
        Free(strings);
    }
    {
        const auto strings = MakeRandomStrings(1000, length);
        BENCHMARK("1000 strings")
        {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        };
        Free(strings);
    }
    {
        const auto strings = MakeRandomStrings(10000, length);
        BENCHMARK("10000 strings")
        {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        };
        Free(strings);
    }
    {
        const auto strings = MakeRandomStrings(100000, length);
        BENCHMARK("100000 strings")
        {
            FontGeometryInfo::CalculateStringsWidths(strings, font);
        };
        Free(strings);
    }
}
