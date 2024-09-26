// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataFilter.h"
#include "Tests.h"

#define PREFIX "PanelDataFilter "

using namespace nc;
using namespace nc::panel::data;

TEST_CASE(PREFIX "Fuzzy search")
{
    using RIL = std::initializer_list<QuickSearchHiglight::Range>;
    struct TC {
        NSString *filename;
        NSString *text;
        std::optional<QuickSearchHiglight> expected;
    } test_cases[] = {
        {.filename = @"", .text = @"", .expected = QuickSearchHiglight{}},
        {.filename = @"", .text = @"a", .expected = std::nullopt},
        {.filename = @"a", .text = @"", .expected = QuickSearchHiglight{}},
        {.filename = @"a", .text = @"b", .expected = std::nullopt},
        {.filename = @"a", .text = @"a", .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 1}}}},
        {.filename = @"a", .text = @"ab", .expected = std::nullopt},
        {.filename = @"ab", .text = @"ab", .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 2}}}},
        {.filename = @"ba", .text = @"ab", .expected = std::nullopt},
        {.filename = @"aaa", .text = @"a", .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 1}}}},
        {.filename = @"aaa", .text = @"aa", .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 2}}}},
        {.filename = @"aaa", .text = @"aaa", .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 3}}}},
        {.filename = @"abc",
         .text = @"ac",
         .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 1}, {.offset = 2, .length = 1}}}},
        {.filename = @"aab", .text = @"ab", .expected = QuickSearchHiglight{RIL{{.offset = 1, .length = 2}}}},
        {.filename = @"abcabc", .text = @"abc", .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 3}}}},
        {.filename = @"abcabc",
         .text = @"abab",
         .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 2}, {.offset = 3, .length = 2}}}},
        {.filename = @"abcabc", .text = @"cabc", .expected = QuickSearchHiglight{RIL{{.offset = 2, .length = 4}}}},
        {.filename = @"abcabc",
         .text = @"bbc",
         .expected = QuickSearchHiglight{RIL{{.offset = 1, .length = 1}, {.offset = 4, .length = 2}}}},
        {.filename = @"abcabc",
         .text = @"acc",
         .expected = QuickSearchHiglight{RIL{
             {.offset = 0, .length = 1}, {.offset = 2, .length = 1}, {.offset = 5, .length = 1}}}},
        {.filename = @"Calculator.app",
         .text = @"calap",
         .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 3}, {.offset = 11, .length = 2}}}},
        {.filename = @"Calculator.app",
         .text = @"calapp",
         .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 3}, {.offset = 11, .length = 3}}}},
        {.filename = @"Calculator.app",
         .text = @"calcapp",
         .expected = QuickSearchHiglight{RIL{{.offset = 0, .length = 4}, {.offset = 11, .length = 3}}}},
        {.filename = @"Calculator.app",
         .text = @"culap",
         .expected = QuickSearchHiglight{RIL{{.offset = 3, .length = 4}, {.offset = 12, .length = 1}}}},
        {.filename = @"Calculator.app",
         .text = @"app",
         .expected = QuickSearchHiglight{RIL{{.offset = 11, .length = 3}}}},
    };
    for( auto &tc : test_cases ) {
        auto hl = FuzzySearch(tc.filename, tc.text);
        CHECK(hl == tc.expected);
    }
}
