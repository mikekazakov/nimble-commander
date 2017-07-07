#pragma once

#include <VFS/VFS.h>
#include "../Job.h"
#include "Options.h"

namespace nc::ops {

class LinkageJob final : public Job
{
public:
    LinkageJob(const string& _link_path, const string &_link_value,
               const shared_ptr<VFSHost> &_vfs, LinkageType _type);
    ~LinkageJob();
    
private:
    virtual void Perform() override;
    void DoSymlinkCreation();
    void DoSymlinkAlteration();
    void DoHardlinkCreation();

    string m_LinkPath;
    string m_LinkValue;
    VFSHostPtr m_VFS;
    
    LinkageType m_Type;
};

}
