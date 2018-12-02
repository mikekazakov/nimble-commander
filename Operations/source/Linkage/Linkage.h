// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../Operation.h"
#include "Options.h"

namespace nc::ops {

class LinkageJob;

class Linkage final : public Operation
{
public:
    Linkage(const std::string& _link_path, const std::string &_link_value,
            const std::shared_ptr<VFSHost> &_vfs, LinkageType _type);
    ~Linkage();

private:
    virtual Job *GetJob() noexcept override;
    void OnCreateSymlinkError(int _err, const std::string &_path, VFSHost &_vfs);
    void OnAlterSymlinkError(int _err, const std::string &_path, VFSHost &_vfs);
    void OnCreatehardlinkError(int _err, const std::string &_path, VFSHost &_vfs);

    std::unique_ptr<LinkageJob> m_Job;
};

}
