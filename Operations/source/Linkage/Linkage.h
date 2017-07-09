#pragma once

#include "../Operation.h"
#include "Options.h"

class VFSHost;

namespace nc::ops {

class LinkageJob;

class Linkage final : public Operation
{
public:
    Linkage(const string& _link_path, const string &_link_value,
            const shared_ptr<VFSHost> &_vfs, LinkageType _type);
    ~Linkage();

private:
    virtual Job *GetJob() noexcept override;
    void OnCreateSymlinkError(int _err, const string &_path, VFSHost &_vfs);
    void OnAlterSymlinkError(int _err, const string &_path, VFSHost &_vfs);
    void OnCreatehardlinkError(int _err, const string &_path, VFSHost &_vfs);

    unique_ptr<LinkageJob> m_Job;
};

}
