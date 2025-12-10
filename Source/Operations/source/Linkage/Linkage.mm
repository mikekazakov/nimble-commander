// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <memory>

#include "Linkage.h"
#include <Operations/Localizable.h>
#include "LinkageJob.h"
#include "../Internal.h"

namespace nc::ops {

Linkage::Linkage(const std::string &_link_path,
                 const std::string &_link_value,
                 const std::shared_ptr<VFSHost> &_vfs,
                 LinkageType _type)
{
    m_Job = std::make_unique<LinkageJob>(_link_path, _link_value, _vfs, _type);
    m_Job->m_OnCreateSymlinkError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        OnCreateSymlinkError(_err, _path, _vfs);
    };
    m_Job->m_OnAlterSymlinkError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        OnAlterSymlinkError(_err, _path, _vfs);
    };
    m_Job->m_OnCreateHardlinkError = [this](Error _err, const std::string &_path, VFSHost &_vfs) {
        OnCreatehardlinkError(_err, _path, _vfs);
    };
    SetTitle(Caption(_type).UTF8String);
}

Linkage::~Linkage() = default;

Job *Linkage::GetJob() noexcept
{
    return m_Job.get();
}

void Linkage::OnCreateSymlinkError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    ReportHaltReason(localizable::LinkFailedToCreateSymlinkMessage(), _err, _path, _vfs);
}

void Linkage::OnAlterSymlinkError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    ReportHaltReason(localizable::LinkFailedToAlterSymlinkMessage(), _err, _path, _vfs);
}

void Linkage::OnCreatehardlinkError(Error _err, const std::string &_path, VFSHost &_vfs)
{
    ReportHaltReason(localizable::LinkFailedToCreateHardlinkMessage(), _err, _path, _vfs);
}

NSString *Linkage::Caption(LinkageType _type)
{
    if( _type == LinkageType::CreateSymlink )
        return localizable::LinkCreatingNewSymlinkTitle();
    if( _type == LinkageType::AlterSymlink )
        return localizable::LinkAlteringSymlinkTitle();
    if( _type == LinkageType::CreateHardlink )
        return localizable::LinkCreatingHardlinkTitle();
    return @"";
}

} // namespace nc::ops
