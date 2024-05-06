// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <span>

namespace nc::base {

// Close file descriptors starting with _lowfd and above.
void CloseFrom(int _lowfd) noexcept;

// Close file descriptors starting with _lowfd and above, but skip _except.
void CloseFromExcept(int _lowfd, int _except) noexcept;

// Close file descriptors starting with _lowfd and above, but skip _except.
void CloseFromExcept(int _lowfd, std::span<const int> _except) noexcept;

} // namespace nc::base
