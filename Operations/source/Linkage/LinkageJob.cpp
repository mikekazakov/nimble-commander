// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "LinkageJob.h"
#include <RoutedIO/RoutedIO.h>

namespace nc::ops {

LinkageJob::LinkageJob(const string& _link_path, const string &_link_value,
                       const shared_ptr<VFSHost> &_vfs, LinkageType _type):
    m_LinkPath(_link_path),
    m_LinkValue(_link_value),
    m_VFS(_vfs),
    m_Type(_type)
{
    if( _link_path.empty() || _vfs == nullptr )
        throw invalid_argument("LinkageJob: invalid argument");

    Statistics().SetPreferredSource(Statistics::SourceType::Items);
    Statistics().CommitEstimated(Statistics::SourceType::Items, 1);
    
}

LinkageJob::~LinkageJob()
{
}

void LinkageJob::Perform()
{
    if( m_Type == LinkageType::CreateSymlink )
        DoSymlinkCreation();
    else if( m_Type == LinkageType::AlterSymlink )
        DoSymlinkAlteration();
    else if( m_Type == LinkageType::CreateHardlink )
        DoHardlinkCreation();
}

void LinkageJob::DoSymlinkCreation()
{
    const auto rc = m_VFS->CreateSymlink( m_LinkPath.c_str(), m_LinkValue.c_str() );
    if( rc == VFSError::Ok ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
    else {
        m_OnCreateSymlinkError(rc, m_LinkPath, *m_VFS);
        Stop();
    }
}

void LinkageJob::DoSymlinkAlteration()
{
    VFSStat st;
    const auto stat_rc = m_VFS->Stat( m_LinkPath.c_str(), st, VFSFlags::F_NoFollow );
    if( stat_rc != VFSError::Ok ) {
        m_OnAlterSymlinkError(stat_rc, m_LinkPath, *m_VFS);
        Stop();
        return;
    }
    
    if( (st.mode & S_IFMT) != S_IFLNK ) {
        m_OnAlterSymlinkError( VFSError::FromErrno(EEXIST), m_LinkPath, *m_VFS);
        Stop();
        return;
    }
    
    const auto unlink_rc = m_VFS->Unlink( m_LinkPath.c_str() );
    if( unlink_rc != VFSError::Ok ) {
        m_OnAlterSymlinkError(unlink_rc, m_LinkPath, *m_VFS);
        Stop();
        return;
    }
    
    const auto link_rc = m_VFS->CreateSymlink( m_LinkPath.c_str(), m_LinkValue.c_str() );
    if( link_rc == VFSError::Ok ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
    else {
        m_OnAlterSymlinkError(link_rc, m_LinkPath, *m_VFS);
        Stop();
    }
}

void LinkageJob::DoHardlinkCreation()
{
    if( !m_VFS->IsNativeFS() ) {
        m_OnCreateHardlinkError( VFSError::FromErrno(ENOTSUP), m_LinkPath, *m_VFS );
        Stop();
        return;
    }
    
    const auto posix_rc = RoutedIO::Default.link( m_LinkValue.c_str(), m_LinkPath.c_str() );
    if( posix_rc == 0 ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
    else {
        m_OnCreateHardlinkError( VFSError::FromErrno(), m_LinkPath, *m_VFS );
        Stop();
    }
}

}
