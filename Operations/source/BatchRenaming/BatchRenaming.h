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
    
    unique_ptr<BatchRenamingJob> m_Job;
    bool m_SkipAll = false;
};

}
