// Copyright (C) 2020-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VersionCompare.h>
#include "UnitTests_main.h"

using VC = nc::utility::VersionCompare;
using namespace std::string_literals;
#define PREFIX "nc::utility::VersionCompare "

struct Exp {
    const char *lhs;
    const char *rhs;
    int cmp;
};

static constexpr Exp g_Expectations[] = {
    {.lhs = "", .rhs = "", .cmp = 0},
    {.lhs = "0", .rhs = "0", .cmp = 0},
    {.lhs = "1.0", .rhs = "1.1", .cmp = -1},
    {.lhs = "1.0", .rhs = "1.0", .cmp = 0},
    {.lhs = "2.0", .rhs = "1.1", .cmp = 1},
    {.lhs = "0.1", .rhs = "0.0.1", .cmp = 1},
    {.lhs = "0.1", .rhs = "0.1.2", .cmp = -1},
    {.lhs = "1.0 (1234)", .rhs = "1.0 (1235)", .cmp = -1},
    {.lhs = "1.0b1 (1234)", .rhs = "1.0 (1234)", .cmp = -1},
    {.lhs = "1.0b5 (1234)", .rhs = "1.0b5 (1235)", .cmp = -1},
    {.lhs = "1.0b5 (1234)", .rhs = "1.0.1b5 (1234)", .cmp = -1},
    {.lhs = "1.0.1b5 (1234)", .rhs = "1.0.1b6 (1234)", .cmp = -1},
    {.lhs = "2.0.0.2429", .rhs = "2.0.0.2430", .cmp = -1},
    {.lhs = "1.1.1.1818", .rhs = "2.0.0.2430", .cmp = -1},
    {.lhs = "1.5.5", .rhs = "1.5.6a1", .cmp = -1},
    {.lhs = "1.1.0b1", .rhs = "1.1.0b2", .cmp = -1},
    {.lhs = "1.1.1b2", .rhs = "1.1.2b1", .cmp = -1},
    {.lhs = "1.1.1b2", .rhs = "1.1.2a1", .cmp = -1},
    {.lhs = "1.0a1", .rhs = "1.0b1", .cmp = -1},
    {.lhs = "1.0b1", .rhs = "1.0", .cmp = -1},
    {.lhs = "0.9", .rhs = "1.0a1", .cmp = -1},
    {.lhs = "1.0b", .rhs = "1.0b2", .cmp = -1},
    {.lhs = "1.0b10", .rhs = "1.0b11", .cmp = -1},
    {.lhs = "1.0b9", .rhs = "1.0b10", .cmp = -1},
    {.lhs = "1.0rc", .rhs = "1.0", .cmp = -1},
    {.lhs = "1.0b", .rhs = "1.0", .cmp = -1},
    {.lhs = "1.0pre1", .rhs = "1.0", .cmp = -1},
};

TEST_CASE(PREFIX "Check expectations")
{
    VC const vc;
    for( const auto &exp : g_Expectations ) {
        INFO(exp.lhs);
        INFO(exp.rhs);
        CHECK(vc.Compare(exp.lhs, exp.rhs) == exp.cmp);
        CHECK(vc.Compare(exp.rhs, exp.lhs) == -exp.cmp);
    }
}
