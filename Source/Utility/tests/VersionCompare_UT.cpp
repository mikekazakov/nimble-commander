// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
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
    {"", "", 0},
    {"0", "0", 0},
    {"1.0", "1.1", -1},
    {"1.0", "1.0", 0},
    {"2.0", "1.1", 1},
    {"0.1", "0.0.1", 1},
    {"0.1", "0.1.2", -1},
    {"1.0 (1234)", "1.0 (1235)", -1},
    {"1.0b1 (1234)", "1.0 (1234)", -1},
    {"1.0b5 (1234)", "1.0b5 (1235)", -1},
    {"1.0b5 (1234)", "1.0.1b5 (1234)", -1},
    {"1.0.1b5 (1234)", "1.0.1b6 (1234)", -1},
    {"2.0.0.2429", "2.0.0.2430", -1},
    {"1.1.1.1818", "2.0.0.2430", -1},
    {"1.5.5", "1.5.6a1", -1},
    {"1.1.0b1", "1.1.0b2", -1},
    {"1.1.1b2", "1.1.2b1", -1},
    {"1.1.1b2", "1.1.2a1", -1},
    {"1.0a1", "1.0b1", -1},
    {"1.0b1", "1.0", -1},
    {"0.9", "1.0a1", -1},
    {"1.0b", "1.0b2", -1},
    {"1.0b10", "1.0b11", -1},
    {"1.0b9", "1.0b10", -1},
    {"1.0rc", "1.0", -1},
    {"1.0b", "1.0", -1},
    {"1.0pre1", "1.0", -1},
};

TEST_CASE(PREFIX "Check expectations")
{
    VC vc;
    constexpr size_t num = std::size(g_Expectations);
    for( size_t ind = 0; ind != num; ++ind ) {
        const auto &exp = g_Expectations[ind];
        INFO(exp.lhs); 
        INFO(exp.rhs);
        CHECK(vc.Compare(exp.lhs, exp.rhs) == exp.cmp);
        CHECK(vc.Compare(exp.rhs, exp.lhs) == -exp.cmp);
    }
}
