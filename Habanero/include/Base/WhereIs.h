// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <vector>
#include <filesystem>
#include <string_view>

namespace nc::base {

// Searches all directories in $PATH for executables with 'name', returns in the same order.
// Essintially mimicks the 'whereis' command-line tool.
std::vector<std::filesystem::path> WhereIs(std::string_view name);

} // namespace nc::base
