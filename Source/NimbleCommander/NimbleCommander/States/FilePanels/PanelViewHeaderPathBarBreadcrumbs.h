// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewHeader.h"

#include <string>
#include <vector>

namespace nc::panel {

// Builds path bar breadcrumbs from the path strings produced by panel model.
// - verbose_full: may include a "junction" prefix (e.g. VFS origin) before the real POSIX path.
// - dir_with_trailing_slash: directory path, should end with '/' (or will be treated as such).
// - path_without_trailing_slash: POSIX directory path without trailing slash (e.g. "/Users/me").
[[nodiscard]] std::vector<PanelHeaderBreadcrumb>
BuildPanelHeaderBreadcrumbsFromPaths(const std::string &verbose_full,
                                     const std::string &dir_with_trailing_slash,
                                     const std::string &path_without_trailing_slash);

// Returns a clean absolute POSIX path for path-bar actions.
// Guarantees:
// - never empty (returns "/" for invalid/empty input),
// - always starts with '/',
// - has no trailing slash except the root path itself.
[[nodiscard]] std::string NormalizePanelHeaderPOSIXPathForActions(const std::string &path_without_trailing_slash);

// Resolves which POSIX path context-menu actions should use for a hit breadcrumb segment.
// Current-directory segments use the panel directory (fallback), even when the crumb also carries a navigate link
// (e.g. VFS junction root with navigate_to_vfs_path == "/").
[[nodiscard]] std::optional<std::string> ResolvePanelBreadcrumbSegmentPOSIXForMenu(
    bool is_current_directory,
    const std::optional<std::string> &navigate_to_vfs_path,
    const std::optional<std::string> &fallback_posix_path,
    const std::optional<std::string> &plain_path);

} // namespace nc::panel
