// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "LinkageJob.h"
#include <RoutedIO/RoutedIO.h>

namespace nc::ops {

LinkageJob::LinkageJob(const std::string &_link_path,
                       const std::string &_link_value,
                       const std::shared_ptr<VFSHost> &_vfs,
                       LinkageType _type)
    : m_LinkPath(_link_path), m_LinkValue(_link_value), m_VFS(_vfs), m_Type(_type)
{
    if( _link_path.empty() || _vfs == nullptr )
        throw std::invalid_argument("LinkageJob: invalid argument");

    Statistics().SetPreferredSource(Statistics::SourceType::Items);
    Statistics().CommitEstimated(Statistics::SourceType::Items, 1);
}

LinkageJob::~LinkageJob() = default;

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
    const std::expected<void, Error> rc = m_VFS->CreateSymlink(m_LinkPath, m_LinkValue);
    if( rc ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
    else {
        m_OnCreateSymlinkError(rc.error(), m_LinkPath, *m_VFS);
        Stop();
    }
}

void LinkageJob::DoSymlinkAlteration()
{
    const std::expected<VFSStat, Error> st = m_VFS->Stat(m_LinkPath, VFSFlags::F_NoFollow);
    if( !st ) {
        m_OnAlterSymlinkError(st.error(), m_LinkPath, *m_VFS);
        Stop();
        return;
    }

    if( (st->mode & S_IFMT) != S_IFLNK ) {
        m_OnAlterSymlinkError(Error{Error::POSIX, EEXIST}, m_LinkPath, *m_VFS);
        Stop();
        return;
    }

    const std::expected<void, Error> unlink_rc = m_VFS->Unlink(m_LinkPath);
    if( !unlink_rc ) {
        m_OnAlterSymlinkError(unlink_rc.error(), m_LinkPath, *m_VFS);
        Stop();
        return;
    }

    const std::expected<void, Error> link_rc = m_VFS->CreateSymlink(m_LinkPath, m_LinkValue);
    if( link_rc ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
    else {
        m_OnAlterSymlinkError(link_rc.error(), m_LinkPath, *m_VFS);
        Stop();
    }
}

void LinkageJob::DoHardlinkCreation()
{
    if( !m_VFS->IsNativeFS() ) {
        m_OnCreateHardlinkError(VFSError::FromErrno(ENOTSUP), m_LinkPath, *m_VFS);
        Stop();
        return;
    }

    const auto posix_rc = routedio::RoutedIO::Default.link(m_LinkValue.c_str(), m_LinkPath.c_str());
    if( posix_rc == 0 ) {
        Statistics().CommitProcessed(Statistics::SourceType::Items, 1);
    }
    else {
        m_OnCreateHardlinkError(VFSError::FromErrno(), m_LinkPath, *m_VFS);
        Stop();
    }
}

} // namespace nc::ops
