// Copyright (C) 2021-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <span>
#include <cstddef>
#include <filesystem>
#include "Error.h"

namespace nc::base {

// Does write a temp file + rename.
// Path should be an absolute path.
// If _follow_symlink is true, WriteAtomically first follows any symlinks in the existing file path and writes to the
// symlink destination instead of the symlink file itself.
std::expected<void, Error> WriteAtomically(const std::filesystem::path &_path,
                                           std::span<const std::byte> _bytes,
                                           bool _follow_symlink = false) noexcept;

} // namespace nc::base
