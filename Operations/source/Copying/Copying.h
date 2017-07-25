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
    int OnCopyDestExists(const struct stat &_src, const struct stat &_dst, const string &_path);
    void OnCopyDestExistsUI(const struct stat &_src, const struct stat &_dst, const string &_path,
                            shared_ptr<AsyncDialogResponse> _ctx);
    

    unique_ptr<CopyingJob> m_Job;
    FileCopyOperationOptions::ExistBehavior m_ExistBehavior;
    
};

}
