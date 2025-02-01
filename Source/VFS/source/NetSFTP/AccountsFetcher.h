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
    std::expected<std::vector<VFSGroup>, Error> FetchGroups();

private:
    std::expected<std::vector<VFSUser>, Error> GetUsersViaGetent();
    std::expected<std::vector<VFSGroup>, Error> GetGroupsViaGetent();
    std::expected<std::vector<VFSUser>, Error> GetUsersViaOpenDirectory();
    std::expected<std::vector<VFSGroup>, Error> GetGroupsViaOpenDirectory();
    std::optional<std::string> Execute(const std::string &_command);

    LIBSSH2_SESSION *const m_Session;
    const OSType m_OSType;
};

} // namespace nc::vfs::sftp
