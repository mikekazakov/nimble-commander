#pragma once

#include "../Operation.h"
#include <VFS/VFS.h>

namespace nc::ops
{

class CompressionJob;

class Compression : public Operation
{
public:
    Compression(vector<VFSListingItem> _src_files,
                string _dst_root,
                VFSHostPtr _dst_vfs);
    ~Compression();

    string ArchivePath() const;

protected:
    virtual Job *GetJob() override;

private:
    unique_ptr<CompressionJob> m_Job;
};

}
