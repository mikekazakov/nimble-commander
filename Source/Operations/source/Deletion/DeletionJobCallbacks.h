// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/Error.h>
#include <VFS/VFS.h>
#include <functional>
#include <string>
#include "Options.h"

namespace nc::ops {

struct DeletionJobCallbacks {
    enum class ReadDirErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<ReadDirErrorResolution(int _err, const std::string &_path, VFSHost &_vfs)> m_OnReadDirError =
        [](int, const std::string &, VFSHost &) { return ReadDirErrorResolution::Stop; };

    enum class UnlinkErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<UnlinkErrorResolution(int _err, const std::string &_path, VFSHost &_vfs)> m_OnUnlinkError =
        [](int, const std::string &, VFSHost &) { return UnlinkErrorResolution::Stop; };

    enum class RmdirErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<RmdirErrorResolution(int _err, const std::string &_path, VFSHost &_vfs)> m_OnRmdirError =
        [](int, const std::string &, VFSHost &) { return RmdirErrorResolution::Stop; };

    enum class TrashErrorResolution {
        Stop,
        Skip,
        DeletePermanently,
        Retry
    };
    std::function<TrashErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)> m_OnTrashError =
        [](Error, const std::string &, VFSHost &) { return TrashErrorResolution::Stop; };

    enum class LockedItemResolution {
        Stop,
        Skip,
        Unlock,
        Retry
    };
    std::function<LockedItemResolution(Error _err, const std::string &_path, VFSHost &_vfs, DeletionType _type)>
        m_OnLockedItem = [](Error, const std::string &, VFSHost &, DeletionType) { return LockedItemResolution::Stop; };

    enum class UnlockErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<UnlockErrorResolution(int _err, const std::string &_path, VFSHost &_vfs)> m_OnUnlockError =
        [](int, const std::string &, VFSHost &) { return UnlockErrorResolution::Stop; };
};

} // namespace nc::ops
