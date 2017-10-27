// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BatchRenamingJob.h"
#include <Utility/StringExtras.h>

namespace nc::ops {

BatchRenamingJob::BatchRenamingJob(vector<string> _src_paths,
                                   vector<string> _dst_paths,
                                   shared_ptr<VFSHost> _vfs):
    m_Source( move(_src_paths) ),
    m_Destination( move(_dst_paths) ),
    m_VFS( _vfs )
{
    assert( m_Source.size() == m_Destination.size() );
    Statistics().SetPreferredSource(Statistics::SourceType::Items);
}

BatchRenamingJob::~BatchRenamingJob()
{
}

void BatchRenamingJob::Perform()
{
    Statistics().CommitEstimated(Statistics::SourceType::Items, m_Source.size());
    
    for( int i = 0, e = (int)m_Source.size(); i != e; ++i ) {
        if( BlockIfPaused(); IsStopped() )
            return;

        Rename(m_Source[i], m_Destination[i]);
    }
}

void BatchRenamingJob::Rename( const string &_src, const string &_dst )
{
    if( _src == _dst ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);    
        return;
    }
    
    while( true ) {
        const auto dst_exists = m_VFS->Exists( _dst.c_str() );
        
        int rc = VFSError::Ok;
        if( dst_exists && LowercaseEqual(_src, _dst) == false )
            rc = VFSError::FromErrno(EEXIST);
        else
            rc = m_VFS->Rename( _src.c_str(), _dst.c_str() );
        
        if( rc == VFSError::Ok )
            break;
        
        switch( m_OnRenameError(rc, _dst, *m_VFS) ) {
            case RenameErrorResolution::Skip:
                Statistics().CommitSkipped(Statistics::SourceType::Items, 1);
                return;
            case RenameErrorResolution::Stop:
                Stop();
                return;
            case RenameErrorResolution::Retry:
                continue;
        }
    }
    
    Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
}

}
