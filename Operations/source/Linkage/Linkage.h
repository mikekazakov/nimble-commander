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

    unique_ptr<LinkageJob> m_Job;
};

}
