#include "Tests.h"
#include "TextProcessing.h"
#include "IndexedTextLine.h"
#include <Utility/OrthodoxMonospace.h>
#include <Utility/StringExtras.h>
#include <Utility/Encodings.h>
#include <Utility/FontExtras.h>
#include <Habanero/algo.h>

#include <string>
#include <stdint.h>

using namespace nc::viewer;

TEST_CASE("SplitStringIntoLines breaks lines on wrapping width")
{
    const auto str = u"0123456789";
    const auto len = std::char_traits<char16_t>::length(str);
    SECTION( "precisely divisible" ) {
        const auto lines = SplitStringIntoLines(str, len, 40., 10., 10.);
        REQUIRE( lines.size() == 3 );
        CHECK( lines[0].first == 0 );
        CHECK( lines[0].second == 4 );
        CHECK( lines[1].first == 4 );
        CHECK( lines[1].second == 4 );
        CHECK( lines[2].first == 8 );
        CHECK( lines[2].second == 2 );
    }
    SECTION( "no overflow" ) {
        const auto lines = SplitStringIntoLines(str, len, 40., 9., 10.);
        REQUIRE( lines.size() == 3 );
        CHECK( lines[0].first == 0 );
        CHECK( lines[0].second == 4 );
        CHECK( lines[1].first == 4 );
        CHECK( lines[1].second == 4 );
        CHECK( lines[2].first == 8 );
        CHECK( lines[2].second == 2 );
    }
}

TEST_CASE("SplitStringIntoLines breaks lines 0xA or 0xD")
{
    const auto str = u"0123""\x0A""4567""\x0D""89";
    const auto len = std::char_traits<char16_t>::length(str);
    const auto lines = SplitStringIntoLines(str, len, 1000., 10., 10.);
    REQUIRE( lines.size() == 3 );
    CHECK( lines[0].first == 0 );
    CHECK( lines[0].second == 5 );
    CHECK( lines[1].first == 5 );
    CHECK( lines[1].second == 5 );
    CHECK( lines[2].first == 10 );
    CHECK( lines[2].second == 2 );
}

TEST_CASE("SplitStringIntoLines handles tabs")
{
    SECTION("one tab") {
        const auto str = u"aaa	aaa	aa	a	a";
        const auto len = std::char_traits<char16_t>::length(str);
        const auto lines = SplitStringIntoLines(str, len, 50., 10., 40.);
        REQUIRE( lines.size() == 4 );
        CHECK( lines[0].first == 0 );
        CHECK( lines[0].second == 5 );
        CHECK( lines[1].first == 5 );
        CHECK( lines[1].second == 4 );
        CHECK( lines[2].first == 9 );
        CHECK( lines[2].second == 3 );
        CHECK( lines[3].first == 12 );
        CHECK( lines[3].second == 2 );
    }
    SECTION("two tabs") {
        const auto str = u"\taa\ta";
        const auto len = std::char_traits<char16_t>::length(str);
        const auto lines = SplitStringIntoLines(str, len, 80., 10., 40.);
        REQUIRE( lines.size() == 2 );
        CHECK( lines[0].first == 0 );
        CHECK( lines[0].second == 4 );
        CHECK( lines[1].first == 4 );
        CHECK( lines[1].second == 1 );
    }
}

