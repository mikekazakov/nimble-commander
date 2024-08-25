// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <stdint.h>

namespace nc::viewer {

// Enumeration of the possible viewer modes.
// NB! changing this values may cause corruption of the stored history.
enum class ViewMode : uint8_t {
    Text = 0,
    Hex = 1,
    Preview = 2
};

} // namespace nc::viewer
