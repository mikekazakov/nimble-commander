// Copyright (C) 2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"
#include "Highlighting/Style.h"
#include <lexilla/SciLexer.h>

using namespace nc::viewer::hl;

#define PREFIX "hl::Style "

TEST_CASE(PREFIX "StyleMapper")
{
    StyleMapper sm;
    SECTION("Empty, negative values")
    {
        std::array<char, 2> src = {-1, -128};
        std::array<Style, 2> dst = {Style::Operator, Style::Operator};
        sm.MapStyles(src, dst);
        CHECK(dst[0] == Style::Default);
        CHECK(dst[1] == Style::Default);
    }
    SECTION("Empty, OOB")
    {
        std::array<char, 3> src = {0, 100, 127};
        std::array<Style, 3> dst = {Style::Operator, Style::Operator, Style::Operator};
        sm.MapStyles(src, dst);
        CHECK(dst[0] == Style::Default);
        CHECK(dst[1] == Style::Default);
        CHECK(dst[2] == Style::Default);
    }
    SECTION("Random value")
    {
        std::array<char, 2> src = {SCE_C_STRINGRAW, SCE_C_NUMBER};
        std::array<Style, 2> dst = {Style::Operator, Style::Operator};
        sm.SetMapping(SCE_C_STRINGRAW, Style::String);
        sm.MapStyles(src, dst);
        CHECK(dst[0] == Style::String);
        CHECK(dst[1] == Style::Default);
    }
}
