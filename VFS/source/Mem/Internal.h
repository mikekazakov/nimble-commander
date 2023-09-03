// Copyright (C) 2020-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <unordered_map>
#include <variant>
#include <string>
#include <memory>

namespace nc::vfs::mem {

struct DirectoryEntry;

struct Directory {
    std::unordered_map<std::string, std::shared_ptr<DirectoryEntry>> entries;
};

struct Reg {
};

struct Symlink {
};

struct DirectoryEntry {
    std::variant<Directory, Reg, Symlink> body;
};

} // namespace nc::vfs::mem
