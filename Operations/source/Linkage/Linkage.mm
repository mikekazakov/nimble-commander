#include "Linkage.h"
#include "LinkageJob.h"

namespace nc::ops {

Linkage::Linkage(const string& _link_path, const string &_link_value,
                 const shared_ptr<VFSHost> &_vfs, LinkageType _type)
{
    m_Job.reset( new LinkageJob(_link_path, _link_value, _vfs, _type) );
}

Linkage::~Linkage()
{
}

Job *Linkage::GetJob() noexcept
{
    return m_Job.get();
}

}
