#pragma once

#include "../Operation.h"
#include "Options.h"

class VFSListingItem;
class VFSHost;

namespace nc::ops {

class CopyingJob;

class Copying : public Operation
{
public:
    Copying(vector<VFSListingItem> _source_files,
            const string& _destination_path,
            const shared_ptr<VFSHost> &_destination_host,
            const FileCopyOperationOptions &_options);
    ~Copying();

private:
    virtual Job *GetJob() noexcept override;
    void SetupCallbacks();
    int OnCopyDestExists(const struct stat &_src, const struct stat &_dst, const string &_path);
    void OnCopyDestExistsUI(const struct stat &_src, const struct stat &_dst, const string &_path,
                            shared_ptr<AsyncDialogResponse> _ctx);
    int OnRenameDestExists(const struct stat &_src, const struct stat &_dst, const string &_path);
    void OnRenameDestExistsUI(const struct stat &_src, const struct stat &_dst, const string &_path,
                            shared_ptr<AsyncDialogResponse> _ctx);
    int OnCantAccessSourceItem(int _vfs_error, const string &_path, VFSHost &_vfs);
    int OnCantOpenDestinationFile(int _vfs_error, const string &_path, VFSHost &_vfs);
    int OnSourceFileReadError(int _vfs_error, const string &_path, VFSHost &_vfs);
    int OnDestinationFileReadError(int _vfs_error, const string &_path, VFSHost &_vfs);
    int OnDestinationFileWriteError(int _vfs_error, const string &_path, VFSHost &_vfs);
    void OnCantCreateDestinationRootDir(int _vfs_error, const string &_path, VFSHost &_vfs);
    int OnCantCreateDestinationDir(int _vfs_error, const string &_path, VFSHost &_vfs);
    void OnFileVerificationFailed(const string &_path, VFSHost &_vfs);

    unique_ptr<CopyingJob> m_Job;
    FileCopyOperationOptions::ExistBehavior m_ExistBehavior;
    bool m_SkipAll = false;
};

}
