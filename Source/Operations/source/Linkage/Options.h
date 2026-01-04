// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::ops {

enum class LinkageType : unsigned char {
    CreateSymlink,
    AlterSymlink,
    CreateHardlink
};

} // namespace nc::ops
