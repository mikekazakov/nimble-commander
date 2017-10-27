// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../Job.h"
#include "Options.h"

namespace nc::ops {

struct LinkageJobCallbacks
{
    function< void(int _err, const string &_path, VFSHost &_vfs) >
    m_OnCreateSymlinkError =
    [](int _err, const string &_path, VFSHost &_vfs){};
    
    function< void(int _err, const string &_path, VFSHost &_vfs) >
    m_OnAlterSymlinkError =
    [](int _err, const string &_path, VFSHost &_vfs){};

    function< void(int _err, const string &_path, VFSHost &_vfs) >
    m_OnCreateHardlinkError =
    [](int _err, const string &_path, VFSHost &_vfs){};
};

class LinkageJob final : public Job, public LinkageJobCallbacks
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
