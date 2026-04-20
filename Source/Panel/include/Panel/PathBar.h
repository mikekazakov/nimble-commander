// Copyright (C) 2016-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#import <Foundation/NSString.h>

#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace nc::panel {

// One visual segment in the directory path bar.
// When navigate_to_vfs_path is set, the segment is a link to that absolute path on the current
// panel VFS. The last segment omits it and is shown as plain text (current folder).
struct PanelHeaderBreadcrumb {
    NSString *_Nullable label = nil;
    std::optional<std::string> navigate_to_vfs_path;
    bool is_current_directory = false;
};

// Path strings produced by the panel model, used to build breadcrumbs.
struct PanelPathContext {
    std::string verbose_full_path; // may include a "junction" prefix (e.g. VFS origin)
    std::string directory_path;    // should end with '/'
    std::string posix_path;        // directory path without a trailing slash, e.g. "/Users/me"
};

// Builds path bar breadcrumbs from the path strings produced by the panel model.
[[nodiscard]] std::vector<PanelHeaderBreadcrumb>
BuildPanelHeaderBreadcrumbs(const PanelPathContext &path_context);

// Returns a clean absolute POSIX path for path-bar actions.
// Guarantees: never empty (returns "/" for invalid/empty input), always starts with '/',
// no trailing slash except the root path itself.
[[nodiscard]] std::string NormalizePanelHeaderPOSIXPathForActions(std::string_view path);

// Resolves which POSIX path context-menu actions should use for a hit breadcrumb segment.
// Current-directory segments use the panel directory (fallback), even when the crumb also
// carries a navigate link (e.g. VFS junction root with navigate_to_vfs_path == "/").
[[nodiscard]] std::optional<std::string>
ResolvePanelBreadcrumbSegmentPOSIXForMenu(bool is_current_directory,
                                          const std::optional<std::string> &navigate_to_vfs_path,
                                          const std::optional<std::string> &fallback_posix_path,
                                          const std::optional<std::string> &plain_path);

} // namespace nc::panel
