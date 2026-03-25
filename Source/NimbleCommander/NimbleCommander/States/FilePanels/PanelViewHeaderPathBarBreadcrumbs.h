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

} // namespace nc::panel

