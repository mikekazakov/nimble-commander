#include "Compression.h"
#include "CompressionJob.h"

namespace nc::ops
{

Compression::Compression(vector<VFSListingItem> _src_files,
                         string _dst_root,
                         VFSHostPtr _dst_vfs)
{
    m_Job.reset( new CompressionJob{_src_files,
                                    _dst_root,
                                    _dst_vfs} );
    
    
}

Compression::~Compression()
{
}
    
Job *Compression::GetJob()
{
    return m_Job.get();
}

string Compression::ArchivePath() const
{
    return m_Job->TargetArchivePath();
}





}
