// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSDeclarations.h>
#include <string_view>
#include <functional>

namespace nc::ops {

enum class ItemStatus {
    Processed = 0,
    Skipped = 1
};

struct ItemStateReport {
    VFSHost &host;
    std::string_view path;
    ItemStatus status;
};

using ItemStateReportCallback = std::function<void(ItemStateReport _report)>;

} // namespace nc::ops
