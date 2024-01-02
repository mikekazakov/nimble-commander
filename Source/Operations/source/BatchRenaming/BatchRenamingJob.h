// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include <VFS/VFS.h>

namespace nc::ops {

struct BatchRenamingJobCallbacks
{
    enum class RenameErrorResolution { Stop, Skip, Retry };
    std::function< RenameErrorResolution(int _err, const std::string &_path, VFSHost &_vfs) >
    m_OnRenameError =
    [](int, const std::string &, VFSHost &){ return RenameErrorResolution::Stop; };
};

class BatchRenamingJob final : public Job, public BatchRenamingJobCallbacks
{
public:
    BatchRenamingJob(std::vector<std::string> _src_paths,
                     std::vector<std::string> _dst_paths,
                     std::shared_ptr<VFSHost> _vfs);
    ~BatchRenamingJob();
    
private:
    virtual void Perform() override;
    void Rename( const std::string &_src, const std::string &_dst );

    std::vector<std::string> m_Source;
    std::vector<std::string> m_Destination;
    std::shared_ptr<VFSHost> m_VFS;
};

}
