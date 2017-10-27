// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <libssh2.h>
#include "OSType.h"
#include <VFS/VFSDeclarations.h>

namespace nc::vfs::sftp {

class AccountsFetcher
{
public:
    AccountsFetcher( LIBSSH2_SESSION *_session, OSType _os_type );

    int FetchUsers(vector<VFSUser> &_target);
    int FetchGroups(vector<VFSGroup> &_target);

private:
    int GetUsersViaGetent( vector<VFSUser> &_target );
    int GetGroupsViaGetent( vector<VFSGroup> &_target );
    int GetUsersViaOpenDirectory( vector<VFSUser> &_target );
    int GetGroupsViaOpenDirectory( vector<VFSGroup> &_target );
    optional<string> Execute( const string &_command );

    LIBSSH2_SESSION *const m_Session;
    const OSType m_OSType;
};

}
