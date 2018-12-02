// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::ops {

struct AttrsChangingCommand
{
    struct Permissions {
        std::optional<bool> usr_r;
        std::optional<bool> usr_w;
        std::optional<bool> usr_x;
        std::optional<bool> grp_r;
        std::optional<bool> grp_w;
        std::optional<bool> grp_x;
        std::optional<bool> oth_r;
        std::optional<bool> oth_w;
        std::optional<bool> oth_x;
        std::optional<bool> suid;
        std::optional<bool> sgid;
        std::optional<bool> sticky;
    };
    std::optional<Permissions> permissions;
    
    struct Ownage {
        std::optional<unsigned> uid;
        std::optional<unsigned> gid;
    };
    std::optional<Ownage> ownage;

    struct Flags { // currently assumes only a native MacOSX interface, not a Posix/VFS layer
        std::optional<bool> u_nodump;
        std::optional<bool> u_immutable;
        std::optional<bool> u_append;
        std::optional<bool> u_opaque;
        std::optional<bool> u_tracked;
        std::optional<bool> u_hidden;
        std::optional<bool> u_compressed;
        std::optional<bool> u_datavault;
        std::optional<bool> s_archived;
        std::optional<bool> s_immutable;
        std::optional<bool> s_append;
        std::optional<bool> s_restricted;
        std::optional<bool> s_nounlink;
    };
    std::optional<Flags> flags;

    struct Times {
        std::optional<long> atime;
        std::optional<long> mtime;
        std::optional<long> ctime;
        std::optional<long> btime;
    };
    std::optional<Times> times;
    
    std::vector<VFSListingItem> items;
    bool apply_to_subdirs = false;
};

}
