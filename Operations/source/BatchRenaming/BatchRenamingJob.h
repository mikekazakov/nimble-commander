// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include <VFS/VFS.h>

namespace nc::ops {

struct BatchRenamingJobCallbacks
{
    enum class RenameErrorResolution { Stop, Skip, Retry };
    function< RenameErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_OnRenameError =
    [](int _err, const string &_path, VFSHost &_vfs){ return RenameErrorResolution::Stop; };
};

class BatchRenamingJob final : public Job, public BatchRenamingJobCallbacks
{
public:
    BatchRenamingJob(vector<string> _src_paths,
                     vector<string> _dst_paths,
                     shared_ptr<VFSHost> _vfs);
    ~BatchRenamingJob();
    
private:
    virtual void Perform() override;
    void Rename( const string &_src, const string &_dst );

    vector<string> m_Source;
    vector<string> m_Destination;
    shared_ptr<VFSHost> m_VFS;
};

}
