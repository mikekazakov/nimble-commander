// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

namespace nc::vfs::sftp {

enum class OSType : unsigned char {
    Unknown = 0,
    MacOSX = 1,
    Linux = 2,
    xBSD = 3
};

} // namespace nc::vfs::sftp
