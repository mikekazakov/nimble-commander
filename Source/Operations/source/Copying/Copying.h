// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../Operation.h"
#include "Options.h"
#include "CopyingJobCallbacks.h"

namespace nc::ops {

class CopyingJob;

class Copying : public Operation
{
public:
    Copying(std::vector<VFSListingItem> _source_files,
            const std::string &_destination_path,
            const std::shared_ptr<VFSHost> &_destination_host,
            const CopyingOptions &_options);
    ~Copying();

    void SetCallbackHooks(const CopyingJobCallbacks *_callbacks);

private:
    using CB = CopyingJobCallbacks;

    enum class LockedItemCause {
        Moving,
        Deletion,
        Opening
    };

    virtual Job *GetJob() noexcept override;
    void SetupCallbacks();

    CB::CopyDestExistsResolution
    OnCopyDestExists(const struct stat &_src, const struct stat &_dst, const std::string &_path);
    void OnCopyDestExistsUI(const struct stat &_src,
                            const struct stat &_dst,
                            const std::string &_path,
                            std::shared_ptr<AsyncDialogResponse> _ctx);

    CB::RenameDestExistsResolution
    OnRenameDestExists(const struct stat &_src, const struct stat &_dst, const std::string &_path);
    void OnRenameDestExistsUI(const struct stat &_src,
                              const struct stat &_dst,
                              const std::string &_path,
                              std::shared_ptr<AsyncDialogResponse> _ctx);

    CB::CantAccessSourceItemResolution OnCantAccessSourceItem(Error _error, const std::string &_path, VFSHost &_vfs);

    CB::CantOpenDestinationFileResolution
    OnCantOpenDestinationFile(Error _error, const std::string &_path, VFSHost &_vfs);

    CB::SourceFileReadErrorResolution OnSourceFileReadError(int _vfs_error, const std::string &_path, VFSHost &_vfs);

    CB::DestinationFileReadErrorResolution
    OnDestinationFileReadError(Error _error, const std::string &_path, VFSHost &_vfs);

    CB::DestinationFileWriteErrorResolution
    OnDestinationFileWriteError(Error _error, const std::string &_path, VFSHost &_vfs);

    CB::CantCreateDestinationRootDirResolution
    OnCantCreateDestinationRootDir(Error _error, const std::string &_path, VFSHost &_vfs);

    CB::CantCreateDestinationDirResolution
    OnCantCreateDestinationDir(Error _error, const std::string &_path, VFSHost &_vfs);

    CB::CantDeleteDestinationFileResolution
    OnCantDeleteDestinationFile(Error _error, const std::string &_path, VFSHost &_vfs);

    CB::CantDeleteSourceFileResolution OnCantDeleteSourceItem(Error _error, const std::string &_path, VFSHost &_vfs);

    CB::NotADirectoryResolution OnNotADirectory(const std::string &_path, VFSHost &_vfs);

    CB::UnlockErrorResolution OnUnlockError(Error _error, const std::string &_path, VFSHost &_vfs);

    CB::LockedItemResolution
    OnLockedItemIssue(Error _error, const std::string &_path, VFSHost &_vfs, LockedItemCause _cause);

    void OnLockedItemIssueUI(Error _err,
                             const std::string &_path,
                             std::shared_ptr<VFSHost> _vfs,
                             LockedItemCause _cause,
                             std::shared_ptr<AsyncDialogResponse> _ctx);

    void OnFileVerificationFailed(const std::string &_path, VFSHost &_vfs);
    void OnStageChanged();

    std::unique_ptr<CopyingJob> m_Job;
    const CopyingJobCallbacks *m_CallbackHooks = nullptr;
    CopyingOptions::ExistBehavior m_ExistBehavior;
    CopyingOptions::LockedItemBehavior m_LockedBehaviour;
    bool m_SkipAll = false;
};

} // namespace nc::ops
