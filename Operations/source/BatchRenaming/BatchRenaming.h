#pragma once

#include "../Operation.h"

class VFSHost;

namespace nc::ops {

class BatchRenamingJob;

class BatchRenaming final : public Operation
{
public:
    BatchRenaming(vector<string> _src_paths,
                  vector<string> _dst_paths,
                  shared_ptr<VFSHost> _vfs);
    ~BatchRenaming();

private:
    virtual Job *GetJob() noexcept override;
    int OnRenameError(int _err, const string &_path, VFSHost &_vfs);
    void OnRenameErrorUI(int _err, const string &_path, shared_ptr<VFSHost> _vfs,
                         shared_ptr<AsyncDialogResponse> _ctx);
    
    unique_ptr<BatchRenamingJob> m_Job;
    bool m_SkipAll = false;
};

}
