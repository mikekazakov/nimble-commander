// Copyright (C) 2013-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS_fwd.h>

#include <cstddef>

namespace nc::utility {
class TemporaryFileStorage;
}

namespace nc::panel {

// TODO: there's actually nothing specific to QuickLook here, the same mechanism can be used e.g. for iconForFile:...
class QuickLookVFSBridge
{
public:
    QuickLookVFSBridge(nc::utility::TemporaryFileStorage &_storage,
                       uint64_t _max_size = static_cast<uint64_t>(64 * 1024 * 1024));

    // Synchronously fetches the item at the specified path from the specified host into a temporary storage on the real
    // native filesystem.
    // In case the total size of the item (including subdirectories and files) exceeds m_MaxSize, an nil is returned.
    // By providing a cancel checker, the operation can be cancelled from outside. In this case, nil is returned.
    NSURL *FetchItem(const std::string &_path, VFSHost &_host, const std::function<bool()> &_cancel_checker = {});

private:
    nc::utility::TemporaryFileStorage &m_TempStorage;
    uint64_t m_MaxSize;
};

} // namespace nc::panel
