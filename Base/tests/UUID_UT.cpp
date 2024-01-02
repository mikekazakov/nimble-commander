// Copyright (C) 2023 Michael Kazakov. Subject to GNU General Public License version 3.
#include "UUID.h"
#include "UnitTests_main.h"

using namespace nc::base;

TEST_CASE("nc::base::UUID")
{
    CHECK(UUID{}.ToString() == "00000000-0000-0000-0000-000000000000");
    CHECK(!UUID::FromString("df69ae86-c4f6-4bab-af46-fd97e764868"));
    CHECK(!UUID::FromString("df6-ae86-c4f6-4bab-af46-fd97e764868c"));
    CHECK(!UUID::FromString("df6-ae86-c4f6-4bab-af46-fd97e764868c"));
    CHECK(!UUID::FromString("df69ae86-c4f6-4bab-af46afd97e764868c"));
    CHECK(UUID::FromString("df69ae86-c4f6-4bab-af46-fd97e764868c").value().ToString() ==
          "df69ae86-c4f6-4bab-af46-fd97e764868c");
    CHECK(UUID::FromString("df69ae86-c4f6-4bab-af46-fd97e764868c").value() ==
          UUID::FromString("df69ae86-c4f6-4bab-af46-fd97e764868c").value());
    CHECK(UUID::FromString("df69ae86-c4f6-4bab-af46-fd97e764868c").value() !=
          UUID::FromString("df69ae86-c4f6-4bab-af46-fd97e764868d").value());
    CHECK(UUID::Generate() != UUID::Generate());
    CHECK(UUID::Generate() != UUID{});
}
