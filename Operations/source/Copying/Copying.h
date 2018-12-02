// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../Operation.h"
#include "Options.h"

namespace nc::ops {

class CopyingJob;

class Copying : public Operation
{
public:
    Copying(std::vector<VFSListingItem> _source_files,
            const std::string& _destination_path,
            const std::shared_ptr<VFSHost> &_destination_host,
            const CopyingOptions &_options);
    ~Copying();

private:
    virtual Job *GetJob() noexcept override;
    void SetupCallbacks();
    int OnCopyDestExists(const struct stat &_src, const struct stat &_dst, const std::string &_path);
    void OnCopyDestExistsUI(const struct stat &_src, const struct stat &_dst, const std::string &_path,
                            std::shared_ptr<AsyncDialogResponse> _ctx);
    int OnRenameDestExists(const struct stat &_src, const struct stat &_dst, const std::string &_path);
    void OnRenameDestExistsUI(const struct stat &_src, const struct stat &_dst, const std::string &_path,
                            std::shared_ptr<AsyncDialogResponse> _ctx);
    int OnCantAccessSourceItem(int _vfs_error, const std::string &_path, VFSHost &_vfs);
    int OnCantOpenDestinationFile(int _vfs_error, const std::string &_path, VFSHost &_vfs);
    int OnSourceFileReadError(int _vfs_error, const std::string &_path, VFSHost &_vfs);
    int OnDestinationFileReadError(int _vfs_error, const std::string &_path, VFSHost &_vfs);
    int OnDestinationFileWriteError(int _vfs_error, const std::string &_path, VFSHost &_vfs);
    int OnCantCreateDestinationRootDir(int _vfs_error, const std::string &_path, VFSHost &_vfs);
    int OnCantCreateDestinationDir(int _vfs_error, const std::string &_path, VFSHost &_vfs);
    int OnCantDeleteDestinationFile(int _vfs_error, const std::string &_path, VFSHost &_vfs);
    int OnCantDeleteSourceItem(int _vfs_error, const std::string &_path, VFSHost &_vfs);
    int OnNotADirectory(const std::string &_path, VFSHost &_vfs);
    void OnFileVerificationFailed(const std::string &_path, VFSHost &_vfs);
    void OnStageChanged();

    std::unique_ptr<CopyingJob> m_Job;
    CopyingOptions::ExistBehavior m_ExistBehavior;
    bool m_SkipAll = false;
};

}
