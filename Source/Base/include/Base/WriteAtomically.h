// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <span>
#include <cstddef>
#include <filesystem>

namespace nc::base {

// Does write a temp file + rename.
// Path should be an absolute path.
// Returns true on success, false otherwise + errno contains an error code.
bool WriteAtomically(const std::filesystem::path &_path, std::span<const std::byte> _bytes) noexcept;

} // namespace nc::base
