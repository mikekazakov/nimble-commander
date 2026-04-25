// Copyright (C) 2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Tests.h"

#include <NimbleCommander/States/FilePanels/NCPanelPathBarPresentation.h>

using nc::panel::BuildPanelHeaderBreadcrumbs;
using nc::panel::NormalizePanelHeaderPOSIXPathForActions;
using nc::panel::PanelHeaderBreadcrumb;
using nc::panel::PanelPathContext;
using nc::panel::ResolvePanelBreadcrumbSegmentPOSIXForMenu;

#define PREFIX "NCPanelPathBarPresentation "

static std::string ToUTF8(NSString *s)
{
    if( !s )
        return {};
    const char *const p = s.UTF8String;
    return p ? std::string{p} : std::string{};
}

TEST_CASE(PREFIX "Root without junction")
{
    const auto crumbs = BuildPanelHeaderBreadcrumbs({"/", "/", "/"});
    REQUIRE(crumbs.size() == 1);
    CHECK(ToUTF8(crumbs[0].label) == "/");
    CHECK(!crumbs[0].navigate_to_vfs_path.has_value());
    CHECK(crumbs[0].is_current_directory);
}

TEST_CASE(PREFIX "Simple path without junction")
{
    const auto crumbs = BuildPanelHeaderBreadcrumbs({"/Users/me/Projects/", "/Users/me/Projects/", "/Users/me/Projects"});
    REQUIRE(crumbs.size() == 4);
    CHECK(ToUTF8(crumbs[0].label) == "/");
    CHECK(crumbs[0].navigate_to_vfs_path == "/");
    CHECK(!crumbs[0].is_current_directory);

    CHECK(ToUTF8(crumbs[1].label) == "Users");
    CHECK(crumbs[1].navigate_to_vfs_path == "/Users");
    CHECK(!crumbs[1].is_current_directory);

    CHECK(ToUTF8(crumbs[2].label) == "me");
    CHECK(crumbs[2].navigate_to_vfs_path == "/Users/me");
    CHECK(!crumbs[2].is_current_directory);

    CHECK(ToUTF8(crumbs[3].label) == "Projects");
    CHECK(!crumbs[3].navigate_to_vfs_path.has_value()); // current dir segment
    CHECK(crumbs[3].is_current_directory);
}

TEST_CASE(PREFIX "Root with junction prefix")
{
    const auto crumbs = BuildPanelHeaderBreadcrumbs({"sftp://host/", "/", "/"});
    REQUIRE(crumbs.size() == 1);
    CHECK(ToUTF8(crumbs[0].label) == "sftp://host");
    CHECK(crumbs[0].navigate_to_vfs_path == "/");
    CHECK(crumbs[0].is_current_directory);
}

TEST_CASE(PREFIX "Non-root with junction prefix")
{
    const auto crumbs = BuildPanelHeaderBreadcrumbs({"sftp://host/Users/me/", "/Users/me/", "/Users/me"});
    REQUIRE(crumbs.size() == 3);
    CHECK(ToUTF8(crumbs[0].label) == "sftp://host");
    CHECK(crumbs[0].navigate_to_vfs_path == "/");
    CHECK(!crumbs[0].is_current_directory);

    CHECK(ToUTF8(crumbs[1].label) == "Users");
    CHECK(crumbs[1].navigate_to_vfs_path == "/Users");
    CHECK(!crumbs[1].is_current_directory);

    CHECK(ToUTF8(crumbs[2].label) == "me");
    CHECK(!crumbs[2].navigate_to_vfs_path.has_value());
    CHECK(crumbs[2].is_current_directory);
}

TEST_CASE(PREFIX "Normalizes POSIX path for actions")
{
    CHECK(NormalizePanelHeaderPOSIXPathForActions("") == "/");
    CHECK(NormalizePanelHeaderPOSIXPathForActions("/") == "/");
    CHECK(NormalizePanelHeaderPOSIXPathForActions("/Users/me") == "/Users/me");
    CHECK(NormalizePanelHeaderPOSIXPathForActions("/Users/me/") == "/Users/me");
    CHECK(NormalizePanelHeaderPOSIXPathForActions("Users/me") == "/Users/me");
}

TEST_CASE(PREFIX "Junction root current segment uses panel path for menu actions, not navigate link")
{
    // Model: single crumb "sftp://host" with navigate "/" and isCurrentDirectory (see Root with junction prefix).
    const auto r = ResolvePanelBreadcrumbSegmentPOSIXForMenu(true, "/", "/", std::nullopt);
    REQUIRE(r.has_value());
    CHECK(*r == "/");
}

TEST_CASE(PREFIX "Context menu path: parent link still uses navigate target")
{
    const auto r = ResolvePanelBreadcrumbSegmentPOSIXForMenu(false, "/Users", "/Users/me", std::nullopt);
    REQUIRE(r.has_value());
    CHECK(*r == "/Users");
}

TEST_CASE(PREFIX "Non-current segment without navigate uses fallback or plain path")
{
    CHECK(!ResolvePanelBreadcrumbSegmentPOSIXForMenu(false, std::nullopt, std::nullopt, std::nullopt).has_value());
    const auto fb = ResolvePanelBreadcrumbSegmentPOSIXForMenu(false, std::nullopt, "/x", std::nullopt);
    REQUIRE(fb.has_value());
    CHECK(*fb == "/x");
    const auto pl = ResolvePanelBreadcrumbSegmentPOSIXForMenu(false, std::nullopt, std::nullopt, "/plain");
    REQUIRE(pl.has_value());
    CHECK(*pl == "/plain");
}
