// Copyright (C) 2023-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataFilter.h"
#include "Tests.h"

#define PREFIX "PanelDataFilter "

namespace {

using namespace nc;
using namespace nc::panel::data;

TEST_CASE(PREFIX "Fuzzy search")
{
    using RIL = std::initializer_list<QuickSearchHighlight::Range>;
    struct TC {
        NSString *filename;
        NSString *text;
        std::optional<QuickSearchHighlight> expected;
    } test_cases[] = {
        {.filename = @"", .text = @"", .expected = QuickSearchHighlight{}},
        {.filename = @"", .text = @"a", .expected = std::nullopt},
        {.filename = @"a", .text = @"", .expected = QuickSearchHighlight{}},
        {.filename = @"a", .text = @"b", .expected = std::nullopt},
        {.filename = @"a", .text = @"a", .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 1}}}},
        {.filename = @"a", .text = @"ab", .expected = std::nullopt},
        {.filename = @"ab", .text = @"ab", .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 2}}}},
        {.filename = @"ba", .text = @"ab", .expected = std::nullopt},
        {.filename = @"aaa", .text = @"a", .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 1}}}},
        {.filename = @"aaa", .text = @"aa", .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 2}}}},
        {.filename = @"aaa", .text = @"aaa", .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 3}}}},
        {.filename = @"abc",
         .text = @"ac",
         .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 1}, {.offset = 2, .length = 1}}}},
        {.filename = @"aab", .text = @"ab", .expected = QuickSearchHighlight{RIL{{.offset = 1, .length = 2}}}},
        {.filename = @"abcabc", .text = @"abc", .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 3}}}},
        {.filename = @"abcabc",
         .text = @"abab",
         .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 2}, {.offset = 3, .length = 2}}}},
        {.filename = @"abcabc", .text = @"cabc", .expected = QuickSearchHighlight{RIL{{.offset = 2, .length = 4}}}},
        {.filename = @"abcabc",
         .text = @"bbc",
         .expected = QuickSearchHighlight{RIL{{.offset = 1, .length = 1}, {.offset = 4, .length = 2}}}},
        {.filename = @"abcabc",
         .text = @"acc",
         .expected = QuickSearchHighlight{RIL{
             {.offset = 0, .length = 1}, {.offset = 2, .length = 1}, {.offset = 5, .length = 1}}}},
        {.filename = @"Calculator.app",
         .text = @"calap",
         .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 3}, {.offset = 11, .length = 2}}}},
        {.filename = @"Calculator.app",
         .text = @"calapp",
         .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 3}, {.offset = 11, .length = 3}}}},
        {.filename = @"Calculator.app",
         .text = @"calcapp",
         .expected = QuickSearchHighlight{RIL{{.offset = 0, .length = 4}, {.offset = 11, .length = 3}}}},
        {.filename = @"Calculator.app",
         .text = @"culap",
         .expected = QuickSearchHighlight{RIL{{.offset = 3, .length = 4}, {.offset = 12, .length = 1}}}},
        {.filename = @"Calculator.app",
         .text = @"app",
         .expected = QuickSearchHighlight{RIL{{.offset = 11, .length = 3}}}},
    };
    for( auto &tc : test_cases ) {
        auto hl = FuzzySearch(tc.filename, tc.text);
        CHECK(hl == tc.expected);
    }
}

} // namespace

#undef PREFIX
