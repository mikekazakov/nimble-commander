// Copyright (C) 2021-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <span>
#include <cstddef>
#include <filesystem>
#include "Error.h"

namespace nc::base {

// Does write a temp file + rename.
// Path should be an absolute path.
std::expected<void, Error> WriteAtomically(const std::filesystem::path &_path,
                                           std::span<const std::byte> _bytes) noexcept;

} // namespace nc::base
