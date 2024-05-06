// Copyright (C) 2020-204 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/SystemInformation.h>
#include "UnitTests_main.h"

using namespace nc::utility;
using namespace std::string_literals;
#define PREFIX "nc::utility::GetSystemOverview "

TEST_CASE(PREFIX "Extracts all data", "[!mayfail]")
{
    SystemOverview so;
    REQUIRE(GetSystemOverview(so));
    CHECK(so.user_name.empty() == false);
    CHECK(so.user_full_name.empty() == false);
    CHECK(so.computer_name.empty() == false);
    CHECK(so.coded_model.empty() == false);
    CHECK(so.human_model.empty() == false);
    CHECK(so.human_model != "N/A"); // <<-- getting human model fails on GHA / macOS14 / M1 runners
}
