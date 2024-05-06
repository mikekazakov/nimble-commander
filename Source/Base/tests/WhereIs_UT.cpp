// Copyright (C) 2021-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WhereIs.h"
#include "UnitTests_main.h"
#include <cstdlib>

using nc::base::WhereIs;
using VP = std::vector<std::filesystem::path>;

#define PREFIX "WhereIs "

TEST_CASE(PREFIX "incorrect input")
{
    CHECK(WhereIs("").empty());
    CHECK(WhereIs("/usr/bin/zip").empty());
    CHECK(WhereIs("something_presumably_nonexisting!").empty());
}

TEST_CASE(PREFIX "normal input")
{
    CHECK(WhereIs("ls") == VP{"/bin/ls"});
    CHECK(WhereIs("zip") == VP{"/usr/bin/zip"});
    CHECK(WhereIs("halt") == VP{"/sbin/halt"});
    CHECK(WhereIs("fsck_apfs") == VP{"/sbin/fsck_apfs"});
}

TEST_CASE(PREFIX "works with non-existing directories")
{
    const std::string current_path = std::getenv("PATH");
    const std::string bogus_path = current_path + ":/foo/bar/baz";
    setenv("PATH", bogus_path.c_str(), 1);

    CHECK(WhereIs("ls") == VP{"/bin/ls"});
    CHECK(WhereIs("zip") == VP{"/usr/bin/zip"});
    CHECK(WhereIs("halt") == VP{"/sbin/halt"});
    CHECK(WhereIs("fsck_apfs") == VP{"/sbin/fsck_apfs"});

    setenv("PATH", current_path.c_str(), 1);
}
