// Copyright (C) 2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"

#include <NimbleCommander/States/FilePanels/PanelViewHeaderPathBarBreadcrumbs.h>

using nc::panel::BuildPanelHeaderBreadcrumbsFromPaths;
using nc::panel::PanelHeaderBreadcrumb;

#define PREFIX "PanelViewHeaderPathBarBreadcrumbs "

static std::string ToUTF8(NSString *s)
{
    if( !s )
        return {};
    const char *const p = s.UTF8String;
    return p ? std::string{p} : std::string{};
}

TEST_CASE(PREFIX "Root without junction")
{
    const auto crumbs = BuildPanelHeaderBreadcrumbsFromPaths("/", "/", "/");
    REQUIRE(crumbs.size() == 1);
    CHECK(ToUTF8(crumbs[0].label) == "/");
    CHECK(!crumbs[0].navigate_to_vfs_path.has_value());
}

TEST_CASE(PREFIX "Simple path without junction")
{
    const auto crumbs = BuildPanelHeaderBreadcrumbsFromPaths("/Users/me/Projects/", "/Users/me/Projects/", "/Users/me/Projects");
    REQUIRE(crumbs.size() == 4);
    CHECK(ToUTF8(crumbs[0].label) == "/");
    CHECK(crumbs[0].navigate_to_vfs_path == "/");

    CHECK(ToUTF8(crumbs[1].label) == "Users");
    CHECK(crumbs[1].navigate_to_vfs_path == "/Users");

    CHECK(ToUTF8(crumbs[2].label) == "me");
    CHECK(crumbs[2].navigate_to_vfs_path == "/Users/me");

    CHECK(ToUTF8(crumbs[3].label) == "Projects");
    CHECK(!crumbs[3].navigate_to_vfs_path.has_value()); // current dir segment
}

TEST_CASE(PREFIX "Root with junction prefix")
{
    const auto crumbs = BuildPanelHeaderBreadcrumbsFromPaths("sftp://host/", "/", "/");
    REQUIRE(crumbs.size() == 1);
    CHECK(ToUTF8(crumbs[0].label) == "sftp://host");
    CHECK(crumbs[0].navigate_to_vfs_path == "/");
}

TEST_CASE(PREFIX "Non-root with junction prefix")
{
    const auto crumbs = BuildPanelHeaderBreadcrumbsFromPaths("sftp://host/Users/me/", "/Users/me/", "/Users/me");
    REQUIRE(crumbs.size() == 3);
    CHECK(ToUTF8(crumbs[0].label) == "sftp://host");
    CHECK(crumbs[0].navigate_to_vfs_path == "/");

    CHECK(ToUTF8(crumbs[1].label) == "Users");
    CHECK(crumbs[1].navigate_to_vfs_path == "/Users");

    CHECK(ToUTF8(crumbs[2].label) == "me");
    CHECK(!crumbs[2].navigate_to_vfs_path.has_value());
}

