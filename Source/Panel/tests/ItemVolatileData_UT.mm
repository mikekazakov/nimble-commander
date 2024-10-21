// Copyright (C) 2023-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataItemVolatileData.h"
#include "Tests.h"

#define PREFIX "PanelDataItemVolatileData "

using namespace nc;
// using namespace nc::base;
using namespace nc::panel::data;

using R = QuickSearchHiglight::Range;

TEST_CASE(PREFIX "empty constructor")
{
    const QuickSearchHiglight hl;
    CHECK(hl.size() == 0); // NOLINT
    CHECK(hl.empty() == true);
    const auto r = hl.unpack();
    CHECK(r.count == 0);
}

TEST_CASE(PREFIX "ranges constructor")
{
    SECTION("Empty")
    {
        const QuickSearchHiglight hl(std::span<const R>{});
        CHECK(hl.size() == 0); // NOLINT
        CHECK(hl.empty() == true);
        const auto r = hl.unpack();
        CHECK(r.count == 0);
    }
    SECTION("Single segment")
    {
        const R test_cases[] = {
            {0, 1},   {1, 1},   {15, 1},   {16, 1},  {29, 1},  {30, 1},   {31, 1},  {70, 1},  {120, 1},
            {0, 15},  {15, 15}, {16, 15},  {30, 15}, {31, 15}, {120, 15}, {0, 16},  {15, 16}, {16, 16},
            {30, 16}, {31, 16}, {105, 16}, {0, 30},  {15, 30}, {16, 30},  {29, 30}, {30, 30}, {31, 30},
            {90, 30}, {0, 31},  {15, 31},  {16, 31}, {29, 31}, {30, 31},  {31, 31}, {0, 120},
        };
        for( auto test_case : test_cases ) {
            const QuickSearchHiglight hl({&test_case, 1});
            CHECK(hl.size() == test_case.length);
            CHECK(hl.empty() == false);
            const auto r = hl.unpack();
            CHECK(r.count == 1);
            CHECK(r.segments[0] == test_case);
        }
    }
    SECTION("Multiple segments")
    {
        const QuickSearchHiglight::Ranges test_cases[] = {
            {.segments = {{.offset = 0, .length = 1}, {.offset = 16, .length = 1}}, .count = 2},
            {.segments = {{.offset = 0, .length = 1},
                          {.offset = 5, .length = 1},
                          {.offset = 10, .length = 1},
                          {.offset = 15, .length = 1},
                          {.offset = 20, .length = 1},
                          {.offset = 25, .length = 1}},
             .count = 6},
            {.segments = {{.offset = 0, .length = 1},
                          {.offset = 5, .length = 1},
                          {.offset = 10, .length = 1},
                          {.offset = 15, .length = 1},
                          {.offset = 20, .length = 1},
                          {.offset = 25, .length = 1},
                          {.offset = 30, .length = 1}},
             .count = 7},
            {.segments = {{.offset = 0, .length = 1},
                          {.offset = 5, .length = 1},
                          {.offset = 10, .length = 1},
                          {.offset = 15, .length = 1},
                          {.offset = 20, .length = 1},
                          {.offset = 25, .length = 1},
                          {.offset = 30, .length = 1},
                          {.offset = 35, .length = 1}},
             .count = 8},
            {.segments = {{.offset = 0, .length = 2},
                          {.offset = 5, .length = 2},
                          {.offset = 10, .length = 2},
                          {.offset = 15, .length = 2},
                          {.offset = 20, .length = 2},
                          {.offset = 25, .length = 2},
                          {.offset = 30, .length = 2},
                          {.offset = 35, .length = 2}},
             .count = 8},
            {.segments = {{.offset = 0, .length = 4},
                          {.offset = 5, .length = 4},
                          {.offset = 10, .length = 4},
                          {.offset = 15, .length = 4},
                          {.offset = 20, .length = 4},
                          {.offset = 25, .length = 4},
                          {.offset = 30, .length = 4},
                          {.offset = 35, .length = 4}},
             .count = 8},
            {.segments = {{.offset = 0, .length = 20}, {.offset = 50, .length = 20}}, .count = 2},
        };

        for( auto tc : test_cases ) {
            const QuickSearchHiglight hl({tc.segments, tc.count});
            CHECK(hl.size() == tc.segments[0].length + tc.segments[1].length + tc.segments[2].length +
                                   tc.segments[3].length + tc.segments[4].length + tc.segments[5].length +
                                   tc.segments[6].length + tc.segments[7].length);
            CHECK(hl.empty() == false);
            const auto r = hl.unpack();
            CHECK(r == tc);
        }
    }
    SECTION("Truncation")
    {
        struct TC {
            R src, dst;
        } const tcs[] = {{
            .src = {0, 1000}, .dst = {0, 120},
            // TODO: more?
        }};
        for( auto test_case : tcs ) {
            const QuickSearchHiglight hl({&test_case.src, 1});
            CHECK(hl.size() == test_case.dst.length);
            CHECK(hl.empty() == false);
            const auto r = hl.unpack();
            CHECK(r.count == 1);
            CHECK(r.segments[0].offset == test_case.dst.offset);
            CHECK(r.segments[0].length == test_case.dst.length);
        }
    }
}
