// Copyright (C) 2020-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/SystemInformation.h>
#include "UnitTests_main.h"

#define PREFIX "nc::utility::GetSystemOverview "

namespace {

using namespace nc::utility;
using namespace std::string_literals;

TEST_CASE(PREFIX "Extracts all data")
{
    SystemOverview so;
    REQUIRE(GetSystemOverview(so));
    CHECK(so.user_name.empty() == false);
    CHECK(so.user_full_name.empty() == false);
    CHECK(so.computer_name.empty() == false);
}

} // namespace

#undef PREFIX
