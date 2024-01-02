// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../Job.h"
#include "Options.h"

namespace nc::ops {

struct LinkageJobCallbacks
{
    std::function< void(int _err, const std::string &_path, VFSHost &_vfs) >
    m_OnCreateSymlinkError =
    [](int, const std::string &, VFSHost &){};
    
    std::function< void(int _err, const std::string &_path, VFSHost &_vfs) >
    m_OnAlterSymlinkError =
    [](int, const std::string &, VFSHost &){};

    std::function< void(int _err, const std::string &_path, VFSHost &_vfs) >
    m_OnCreateHardlinkError =
    [](int, const std::string &, VFSHost &){};
};

class LinkageJob final : public Job, public LinkageJobCallbacks
{
public:
    LinkageJob(const std::string& _link_path, const std::string &_link_value,
               const std::shared_ptr<VFSHost> &_vfs, LinkageType _type);
    ~LinkageJob();
    
private:
    virtual void Perform() override;
    void DoSymlinkCreation();
    void DoSymlinkAlteration();
    void DoHardlinkCreation();

    std::string m_LinkPath;
    std::string m_LinkValue;
    VFSHostPtr m_VFS;
    
    LinkageType m_Type;
};

}
