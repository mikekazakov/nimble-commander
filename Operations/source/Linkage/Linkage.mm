// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Linkage.h"
#include "LinkageJob.h"
#include "../Internal.h"

namespace nc::ops {

using Callbacks = LinkageJobCallbacks;

static NSString *Caption( LinkageType _type );


Linkage::Linkage(const std::string& _link_path, const std::string &_link_value,
                 const std::shared_ptr<VFSHost> &_vfs, LinkageType _type)
{
    m_Job.reset( new LinkageJob(_link_path, _link_value, _vfs, _type) );
    m_Job->m_OnCreateSymlinkError = [this](int _err, const std::string &_path, VFSHost &_vfs) {
        OnCreateSymlinkError(_err, _path, _vfs);
    };
    m_Job->m_OnAlterSymlinkError = [this](int _err, const std::string &_path, VFSHost &_vfs) {
        OnAlterSymlinkError(_err, _path, _vfs);
    };
    m_Job->m_OnCreateHardlinkError = [this](int _err, const std::string &_path, VFSHost &_vfs) {
        OnCreatehardlinkError(_err, _path, _vfs);
    };
    SetTitle( Caption(_type).UTF8String );
}

Linkage::~Linkage()
{
}

Job *Linkage::GetJob() noexcept
{
    return m_Job.get();
}

void Linkage::OnCreateSymlinkError(int _err, const std::string &_path, VFSHost &_vfs)
{
    ReportHaltReason(NSLocalizedString(@"Failed to create a symbolic link", ""),
                     _err, _path, _vfs);
}

void Linkage::OnAlterSymlinkError(int _err, const std::string &_path, VFSHost &_vfs)
{
    ReportHaltReason(NSLocalizedString(@"Failed to alter a symbolic link", ""),
                     _err, _path, _vfs);
}

void Linkage::OnCreatehardlinkError(int _err, const std::string &_path, VFSHost &_vfs)
{
    ReportHaltReason(NSLocalizedString(@"Failed to create a hard link", ""),
                     _err, _path, _vfs);
}

static NSString *Caption( LinkageType _type )
{
    if( _type == LinkageType::CreateSymlink )
        return NSLocalizedString(@"Creating a new symbolic link", "");
    if( _type == LinkageType::AlterSymlink )
        return NSLocalizedString(@"Altering a symbolic link", "");
    if( _type == LinkageType::CreateHardlink )
        return NSLocalizedString(@"Creating a new hard link", "");
    return @"";
}

}
