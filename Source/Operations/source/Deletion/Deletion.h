// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../Operation.h"
#include "Options.h"
#include "DeletionJobCallbacks.h"

namespace nc::ops {

class DeletionJob;

class Deletion final : public Operation
{
public:
    Deletion(std::vector<VFSListingItem> _items, DeletionOptions _options);
    ~Deletion();

private:
    virtual Job *GetJob() noexcept override;

    DeletionJobCallbacks::ReadDirErrorResolution OnReadDirError(Error _err, const std::string &_path, VFSHost &_vfs);

    void OnReadDirErrorUI(Error _err,
                          const std::string &_path,
                          std::shared_ptr<VFSHost> _vfs,
                          std::shared_ptr<AsyncDialogResponse> _ctx);

    DeletionJobCallbacks::UnlinkErrorResolution OnUnlinkError(Error _err, const std::string &_path, VFSHost &_vfs);

    void OnUnlinkErrorUI(Error _err,
                         const std::string &_path,
                         std::shared_ptr<VFSHost> _vfs,
                         std::shared_ptr<AsyncDialogResponse> _ctx);

    DeletionJobCallbacks::RmdirErrorResolution OnRmdirError(Error _err, const std::string &_path, VFSHost &_vfs);

    void OnRmdirErrorUI(Error _err,
                        const std::string &_path,
                        std::shared_ptr<VFSHost> _vfs,
                        std::shared_ptr<AsyncDialogResponse> _ctx);

    DeletionJobCallbacks::TrashErrorResolution OnTrashError(Error _err, const std::string &_path, VFSHost &_vfs);

    void OnTrashErrorUI(Error _err,
                        const std::string &_path,
                        std::shared_ptr<VFSHost> _vfs,
                        std::shared_ptr<AsyncDialogResponse> _ctx);

    DeletionJobCallbacks::LockedItemResolution
    OnLockedItem(Error _err, const std::string &_path, VFSHost &_vfs, DeletionType _type);

    void OnLockedItemUI(Error _err,
                        const std::string &_path,
                        std::shared_ptr<VFSHost> _vfs,
                        DeletionType _type,
                        std::shared_ptr<AsyncDialogResponse> _ctx);

    DeletionJobCallbacks::UnlockErrorResolution OnUnlockError(Error _err, const std::string &_path, VFSHost &_vfs);

    void OnUnlockErrorUI(Error _err,
                         const std::string &_path,
                         std::shared_ptr<VFSHost> _vfs,
                         std::shared_ptr<AsyncDialogResponse> _ctx);

    std::unique_ptr<DeletionJob> m_Job;
    bool m_SkipAll = false;
    bool m_DeleteAllOnTrashError = false;
    DeletionOptions::LockedItemBehavior m_LockedItemBehaviour = DeletionOptions::LockedItemBehavior::Ask;
    const DeletionOptions m_OrigOptions;
};

} // namespace nc::ops
