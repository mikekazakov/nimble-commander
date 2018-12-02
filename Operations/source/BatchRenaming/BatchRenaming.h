// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../Operation.h"

namespace nc::ops {

class BatchRenamingJob;

class BatchRenaming final : public Operation
{
public:
    BatchRenaming(std::vector<std::string> _src_paths,
                  std::vector<std::string> _dst_paths,
                  std::shared_ptr<VFSHost> _vfs);
    ~BatchRenaming();

private:
    virtual Job *GetJob() noexcept override;
    int OnRenameError(int _err, const std::string &_path, VFSHost &_vfs);
    
    std::unique_ptr<BatchRenamingJob> m_Job;
    bool m_SkipAll = false;
};

}
