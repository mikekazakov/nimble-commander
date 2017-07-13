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
    int GetUsersFromLinux( vector<VFSUser> &_target );
    int GetGroupsFromLinux( vector<VFSGroup> &_target );
    int GetUsersFromMacOSX( vector<VFSUser> &_target );
    int GetGroupsFromMacOSX( vector<VFSGroup> &_target );
    optional<string> Execute( const string &_command );

    LIBSSH2_SESSION *const m_Session;
    const VFSNetSFTPOSType m_OSType;
};
