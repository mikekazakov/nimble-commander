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
        {@"", @"", QuickSearchHiglight{}},
        {@"", @"a", std::nullopt},
        {@"a", @"", QuickSearchHiglight{}},
        {@"a", @"b", std::nullopt},
        {@"a", @"a", QuickSearchHiglight{RIL{{0, 1}}}},
        {@"a", @"ab", std::nullopt},
        {@"ab", @"ab", QuickSearchHiglight{RIL{{0, 2}}}},
        {@"ba", @"ab", std::nullopt},
        {@"aaa", @"a", QuickSearchHiglight{RIL{{0, 1}}}},
        {@"aaa", @"aa", QuickSearchHiglight{RIL{{0, 2}}}},
        {@"aaa", @"aaa", QuickSearchHiglight{RIL{{0, 3}}}},
        {@"abc", @"ac", QuickSearchHiglight{RIL{{0, 1}, {2, 1}}}},
        {@"aab", @"ab", QuickSearchHiglight{RIL{{1, 2}}}},
        {@"abcabc", @"abc", QuickSearchHiglight{RIL{{0, 3}}}},
        {@"abcabc", @"abab", QuickSearchHiglight{RIL{{0, 2}, {3, 2}}}},
        {@"abcabc", @"cabc", QuickSearchHiglight{RIL{{2, 4}}}},
        {@"abcabc", @"bbc", QuickSearchHiglight{RIL{{1, 1}, {4, 2}}}},
        {@"abcabc", @"acc", QuickSearchHiglight{RIL{{0, 1}, {2, 1}, {5, 1}}}},
        {@"Calculator.app", @"calap", QuickSearchHiglight{RIL{{0, 3}, {11, 2}}}},
        {@"Calculator.app", @"calapp", QuickSearchHiglight{RIL{{0, 3}, {11, 3}}}},
        {@"Calculator.app", @"calcapp", QuickSearchHiglight{RIL{{0, 4}, {11, 3}}}},
        {@"Calculator.app", @"culap", QuickSearchHiglight{RIL{{3, 4}, {12, 1}}}},
        {@"Calculator.app", @"app", QuickSearchHiglight{RIL{{11, 3}}}},
    };
    for( auto &tc : test_cases ) {
        auto hl = FuzzySearch(tc.filename, tc.text);
        CHECK(hl == tc.expected);
    }
}
