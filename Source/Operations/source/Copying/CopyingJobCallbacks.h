// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <functional>
#include <string>
#include <sys/stat.h>

namespace nc::ops {

struct CopyingJobCallbacks {
    enum class CantAccessSourceItemResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<CantAccessSourceItemResolution(Error _error, const std::string &_path, VFSHost &_vfs)>
        m_OnCantAccessSourceItem =
            [](Error, const std::string &, VFSHost &) { return CantAccessSourceItemResolution::Stop; };

    enum class CopyDestExistsResolution {
        Stop,
        Skip,
        Overwrite,
        OverwriteOld,
        Append,
        KeepBoth
    };
    std::function<CopyDestExistsResolution(const struct stat &_src, const struct stat &_dst, const std::string &_path)>
        m_OnCopyDestinationAlreadyExists = [](const struct stat &, const struct stat &, const std::string &) {
            return CopyDestExistsResolution::Stop;
        };

    enum class RenameDestExistsResolution {
        Stop,
        Skip,
        Overwrite,
        OverwriteOld,
        KeepBoth
    };
    std::function<
        RenameDestExistsResolution(const struct stat &_src, const struct stat &_dst, const std::string &_path)>
        m_OnRenameDestinationAlreadyExists = [](const struct stat &, const struct stat &, const std::string &) {
            return RenameDestExistsResolution::Stop;
        };

    enum class CantOpenDestinationFileResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<CantOpenDestinationFileResolution(Error _error, const std::string &_path, VFSHost &_vfs)>
        m_OnCantOpenDestinationFile =
            [](Error, const std::string &, VFSHost &) { return CantOpenDestinationFileResolution::Stop; };

    enum class SourceFileReadErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<SourceFileReadErrorResolution(int _vfs_error, const std::string &_path, VFSHost &_vfs)>
        m_OnSourceFileReadError =
            [](int, const std::string &, VFSHost &) { return SourceFileReadErrorResolution::Stop; };

    enum class DestinationFileReadErrorResolution {
        Stop,
        Skip
    };
    std::function<DestinationFileReadErrorResolution(Error _error, const std::string &_path, VFSHost &_vfs)>
        m_OnDestinationFileReadError =
            [](Error, const std::string &, VFSHost &) { return DestinationFileReadErrorResolution::Stop; };

    enum class DestinationFileWriteErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<DestinationFileWriteErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)>
        m_OnDestinationFileWriteError =
            [](Error, const std::string &, VFSHost &) { return DestinationFileWriteErrorResolution::Stop; };

    enum class CantCreateDestinationRootDirResolution {
        Stop,
        Retry
    };
    std::function<CantCreateDestinationRootDirResolution(Error _error, const std::string &_path, VFSHost &_vfs)>
        m_OnCantCreateDestinationRootDir =
            [](Error, const std::string &, VFSHost &) { return CantCreateDestinationRootDirResolution::Stop; };

    enum class CantCreateDestinationDirResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<CantCreateDestinationDirResolution(Error _error, const std::string &_path, VFSHost &_vfs)>
        m_OnCantCreateDestinationDir =
            [](Error, const std::string &, VFSHost &) { return CantCreateDestinationDirResolution::Stop; };

    enum class CantDeleteDestinationFileResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<CantDeleteDestinationFileResolution(Error _error, const std::string &_path, VFSHost &_vfs)>
        m_OnCantDeleteDestinationFile =
            [](Error, const std::string &, VFSHost &) { return CantDeleteDestinationFileResolution::Stop; };

    enum class CantDeleteSourceFileResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<CantDeleteSourceFileResolution(Error _error, const std::string &_path, VFSHost &_vfs)>
        m_OnCantDeleteSourceItem =
            [](Error, const std::string &, VFSHost &) { return CantDeleteSourceFileResolution::Stop; };

    enum class NotADirectoryResolution {
        Stop,
        Skip,
        Overwrite
    };
    std::function<NotADirectoryResolution(const std::string &_path, VFSHost &_vfs)> m_OnNotADirectory =
        [](const std::string &, VFSHost &) { return NotADirectoryResolution::Stop; };

    enum class LockedItemResolution {
        Stop,
        Skip,
        Unlock,
        Retry
    };
    std::function<LockedItemResolution(Error _error, const std::string &_path, VFSHost &_vfs)>
        m_OnCantRenameLockedItem = [](Error, const std::string &, VFSHost &) { return LockedItemResolution::Stop; };
    std::function<LockedItemResolution(Error _error, const std::string &_path, VFSHost &_vfs)>
        m_OnCantDeleteLockedItem = [](Error, const std::string &, VFSHost &) { return LockedItemResolution::Stop; };
    std::function<LockedItemResolution(int _vfs_error, const std::string &_path, VFSHost &_vfs)>
        m_OnCantOpenLockedItem = [](int, const std::string &, VFSHost &) { return LockedItemResolution::Stop; };

    enum class UnlockErrorResolution {
        Stop,
        Skip,
        Retry
    };
    std::function<UnlockErrorResolution(Error _err, const std::string &_path, VFSHost &_vfs)> m_OnUnlockError =
        [](Error, const std::string &, VFSHost &) { return UnlockErrorResolution::Stop; };

    std::function<void(const std::string &_path, VFSHost &_vfs)> m_OnFileVerificationFailed = [](const std::string &,
                                                                                                 VFSHost &) {};

    std::function<void()> m_OnStageChanged = []() {};
};

} // namespace nc::ops
