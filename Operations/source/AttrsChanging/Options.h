// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::ops {

struct AttrsChangingCommand
{
    struct Permissions {
        optional<bool> usr_r;
        optional<bool> usr_w;
        optional<bool> usr_x;
        optional<bool> grp_r;
        optional<bool> grp_w;
        optional<bool> grp_x;
        optional<bool> oth_r;
        optional<bool> oth_w;
        optional<bool> oth_x;
        optional<bool> suid;
        optional<bool> sgid;
        optional<bool> sticky;
    };
    optional<Permissions> permissions;
    
    struct Ownage {
        optional<unsigned> uid;
        optional<unsigned> gid;
    };
    optional<Ownage> ownage;

    struct Flags { // currently assumes only a native MacOSX interface, not a Posix/VFS layer
        optional<bool> u_nodump;
        optional<bool> u_immutable;
        optional<bool> u_append;
        optional<bool> u_opaque;
        optional<bool> u_tracked;
        optional<bool> u_hidden;
        optional<bool> u_compressed;
        optional<bool> s_archived;
        optional<bool> s_immutable;
        optional<bool> s_append;
        optional<bool> s_restricted;
        optional<bool> s_nounlink;
    };
    optional<Flags> flags;

    struct Times {
        optional<long> atime;
        optional<long> mtime;
        optional<long> ctime;
        optional<long> btime;
    };
    optional<Times> times;
    
    vector<VFSListingItem> items;
    bool apply_to_subdirs = false;
};

}
