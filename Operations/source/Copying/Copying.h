#pragma once

#include "../Operation.h"
#include "Options.h"

class VFSListingItem;
class VFSHost;

namespace nc::ops {

class CopyingJob;

class Copying : public Operation
{
public:

    Copying(vector<VFSListingItem> _source_files,
            const string& _destination_path,
            const shared_ptr<VFSHost> &_destination_host,
            const FileCopyOperationOptions &_options);
    ~Copying();


private:
    virtual Job *GetJob() noexcept override;

    unique_ptr<CopyingJob> m_Job;
};

}
