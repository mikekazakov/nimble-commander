// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <libssh2.h>
#include "OSType.h"
#include <VFS/VFSDeclarations.h>
#include <optional>

namespace nc::vfs::sftp {

class AccountsFetcher
{
public:
    AccountsFetcher( LIBSSH2_SESSION *_session, OSType _os_type );

    int FetchUsers(std::vector<VFSUser> &_target);
    int FetchGroups(std::vector<VFSGroup> &_target);

private:
    int GetUsersViaGetent( std::vector<VFSUser> &_target );
    int GetGroupsViaGetent( std::vector<VFSGroup> &_target );
    int GetUsersViaOpenDirectory( std::vector<VFSUser> &_target );
    int GetGroupsViaOpenDirectory( std::vector<VFSGroup> &_target );
    std::optional<std::string> Execute( const std::string &_command );

    LIBSSH2_SESSION *const m_Session;
    const OSType m_OSType;
};

}
