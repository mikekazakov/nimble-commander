// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FontExtras.h"
#include "UnitTests_main.h"
#include <numbers>
#include <vector>

using nc::utility::FontGeometryInfo;

#define PREFIX "FontExtras "

TEST_CASE(PREFIX "CalculateStringsWidths works for all sizes of input")
{
    const size_t sz = 1'000'000;
    auto font = [NSFont fontWithName:@"Helvetica Neue" size:13];
    std::vector<CFStringRef> vec(sz);
    std::vector<unsigned short> exp(sz);
    for( size_t n = 0; n != sz; ++n ) {
        if( n % 3 == 0 ) {
            vec[n] = CFSTR("Hello");
            exp[n] = 30;
        }
        if( n % 3 == 1 ) {
            vec[n] = CFSTR("World!");
            exp[n] = 38;
        }
        if( n % 3 == 2 ) {
            vec[n] = CFSTR("Bulbasaur");
            exp[n] = 59;
        }
    }

    for( size_t n = 0; n <= sz; n = n <= 16 ? n + 1 : size_t(std::numbers::pi * static_cast<double>(n)) ) {
        auto widths = FontGeometryInfo::CalculateStringsWidths({vec.data(), n}, font);
        CHECK(widths.size() == n);
        CHECK(std::equal(widths.begin(), widths.end(), exp.begin()));
    }
}

TEST_CASE(PREFIX "CalculateStringsWidths treats newlines")
{
    auto font = [NSFont fontWithName:@"Helvetica Neue" size:13];
    CFStringRef str = CFSTR("Hello, \nworld!");
    auto widths = FontGeometryInfo::CalculateStringsWidths({&str, 1}, font);
    REQUIRE(widths.size() == 1);
    REQUIRE(widths[0] == 77);
}
