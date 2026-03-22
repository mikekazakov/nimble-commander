// Copyright (C) 2023-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelDataItemVolatileData.h"
#include "Tests.h"

#define PREFIX "PanelDataItemVolatileData "

namespace {

using namespace nc;
using namespace nc::panel::data;

using R = QuickSearchHighlight::Range;

TEST_CASE(PREFIX "empty constructor")
{
    const QuickSearchHighlight hl;
    CHECK(hl.size() == 0); // NOLINT
    CHECK(hl.empty() == true);
    const auto r = hl.unpack();
    CHECK(r.count == 0);
}

TEST_CASE(PREFIX "ranges constructor")
{
    SECTION("Empty")
    {
        const QuickSearchHighlight hl(std::span<const R>{});
        CHECK(hl.size() == 0); // NOLINT
        CHECK(hl.empty() == true);
        const auto r = hl.unpack();
        CHECK(r.count == 0);
    }
    SECTION("Single segment")
    {
        const R test_cases[] = {
            {.offset = 0, .length = 1},   {.offset = 1, .length = 1},   {.offset = 15, .length = 1},
            {.offset = 16, .length = 1},  {.offset = 29, .length = 1},  {.offset = 30, .length = 1},
            {.offset = 31, .length = 1},  {.offset = 70, .length = 1},  {.offset = 120, .length = 1},
            {.offset = 0, .length = 15},  {.offset = 15, .length = 15}, {.offset = 16, .length = 15},
            {.offset = 30, .length = 15}, {.offset = 31, .length = 15}, {.offset = 120, .length = 15},
            {.offset = 0, .length = 16},  {.offset = 15, .length = 16}, {.offset = 16, .length = 16},
            {.offset = 30, .length = 16}, {.offset = 31, .length = 16}, {.offset = 105, .length = 16},
            {.offset = 0, .length = 30},  {.offset = 15, .length = 30}, {.offset = 16, .length = 30},
            {.offset = 29, .length = 30}, {.offset = 30, .length = 30}, {.offset = 31, .length = 30},
            {.offset = 90, .length = 30}, {.offset = 0, .length = 31},  {.offset = 15, .length = 31},
            {.offset = 16, .length = 31}, {.offset = 29, .length = 31}, {.offset = 30, .length = 31},
            {.offset = 31, .length = 31}, {.offset = 0, .length = 120},
        };
        for( auto test_case : test_cases ) {
            const QuickSearchHighlight hl({&test_case, 1});
            CHECK(hl.size() == test_case.length);
            CHECK(hl.empty() == false);
            const auto r = hl.unpack();
            CHECK(r.count == 1);
            CHECK(r.segments[0] == test_case);
        }
    }
    SECTION("Multiple segments")
    {
        const QuickSearchHighlight::Ranges test_cases[] = {
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
            const QuickSearchHighlight hl({tc.segments, tc.count});
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
            .src = {.offset = 0, .length = 1000},
            .dst = {.offset = 0, .length = 120},
            // TODO: more?
        }};
        for( auto test_case : tcs ) {
            const QuickSearchHighlight hl({&test_case.src, 1});
            CHECK(hl.size() == test_case.dst.length);
            CHECK(hl.empty() == false);
            const auto r = hl.unpack();
            CHECK(r.count == 1);
            CHECK(r.segments[0].offset == test_case.dst.offset);
            CHECK(r.segments[0].length == test_case.dst.length);
        }
    }
}

} // namespace

#undef PREFIX
