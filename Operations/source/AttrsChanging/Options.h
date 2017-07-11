#pragma once

class VFSListingItem;

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
    
    // + flags
    // + times

    vector<VFSListingItem> items;
    bool apply_to_subdirs = false;
};

}
