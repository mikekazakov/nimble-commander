#include "Tests.h"
#include "TextProcessing.h"

#include <string>
#include <stdint.h>

using namespace nc::viewer;

TEST_CASE("ScanHeadingSpacesForBreakPosition")
{
    SECTION("1") {
        const auto str = u"      A";
        const auto len = std::char_traits<char16_t>::length(str);
        auto r = ScanHeadingSpacesForBreakPosition(str, len, 0, 10., 20.);
        CHECK( r == 2 );
    }
    SECTION("2") {
        const auto str = u"      A";
        const auto len = std::char_traits<char16_t>::length(str);
        auto r = ScanHeadingSpacesForBreakPosition(str, len, 0, 10., 200000000.);
        CHECK( r == 0 );
    }
    SECTION("3") {
        const auto str = u"      ";
        const auto len = std::char_traits<char16_t>::length(str);
        auto r = ScanHeadingSpacesForBreakPosition(str, len, 0, 10., 20.);
        CHECK( r == 2 );
    }
    SECTION("4") {
        const auto str = u"      ";
        const auto len = std::char_traits<char16_t>::length(str);
        auto r = ScanHeadingSpacesForBreakPosition(str, len, 0, 10., 2000000.);
        CHECK( r == 6 );
    }
    SECTION("5") {
        auto r = ScanHeadingSpacesForBreakPosition(u"", 0, 0, 10., 2000000.);
        CHECK( r == 0 );
    }
}
