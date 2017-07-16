#pragma once

#include <libssh2.h>
#include "VFSNetSFTPOSType.h"
#include <VFS/VFSDeclarations.h>

class VFSNetSFTPAccountsFetcher
{
public:
    VFSNetSFTPAccountsFetcher( LIBSSH2_SESSION *_session, VFSNetSFTPOSType _os_type );

    int FetchUsers(vector<VFSUser> &_target);
    int FetchGroups(vector<VFSGroup> &_target);

private:
    int GetUsersViaGetent( vector<VFSUser> &_target );
    int GetGroupsViaGetent( vector<VFSGroup> &_target );
    int GetUsersViaOpenDirectory( vector<VFSUser> &_target );
    int GetGroupsViaOpenDirectory( vector<VFSGroup> &_target );
    optional<string> Execute( const string &_command );

    LIBSSH2_SESSION *const m_Session;
    const VFSNetSFTPOSType m_OSType;
};
