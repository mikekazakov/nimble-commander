#include "Copying.h"
#include "CopyingJob.h"

namespace nc::ops {
Copying::Copying(vector<VFSListingItem> _source_files,
                 const string& _destination_path,
                 const shared_ptr<VFSHost> &_destination_host,
                 const FileCopyOperationOptions &_options)
{
    m_Job.reset( new CopyingJob );
    m_Job->Init(_source_files,
                _destination_path,
                _destination_host,
                _options);
}

Copying::~Copying()
{
    Wait();
}

Job *Copying::GetJob() noexcept
{
    return m_Job.get();
}

}
