// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Base/Error.h>
#include <libssh2.h>
#include "OSType.h"
#include <VFS/VFSDeclarations.h>
#include <optional>
#include <expected>

namespace nc::vfs::sftp {

class AccountsFetcher
{
public:
    AccountsFetcher(LIBSSH2_SESSION *_session, OSType _os_type);

    std::expected<std::vector<VFSUser>, Error> FetchUsers();
    int FetchGroups(std::vector<VFSGroup> &_target);

private:
    std::expected<std::vector<VFSUser>, Error> GetUsersViaGetent();
    int GetGroupsViaGetent(std::vector<VFSGroup> &_target);
    std::expected<std::vector<VFSUser>, Error> GetUsersViaOpenDirectory();
    int GetGroupsViaOpenDirectory(std::vector<VFSGroup> &_target);
    std::optional<std::string> Execute(const std::string &_command);

    LIBSSH2_SESSION *const m_Session;
    const OSType m_OSType;
};

} // namespace nc::vfs::sftp
