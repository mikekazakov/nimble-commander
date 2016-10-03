//
//  filesysattr.h
//  Directories
//
//  Created by Michael G. Kazakov on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFS.h>

struct FileSysAttrAlterCommand
{
    enum fsflags {
        fsf_unix_usr_r,     // R for owner
        fsf_unix_usr_w,     // W for owner
        fsf_unix_usr_x,     // X for owner
        fsf_unix_grp_r,     // R for group
        fsf_unix_grp_w,     // W for group
        fsf_unix_grp_x,     // X for group
        fsf_unix_oth_r,     // R for other
        fsf_unix_oth_w,     // W for other
        fsf_unix_oth_x,     // X for other
        fsf_unix_suid,      // set user id on execution
        fsf_unix_sgid,      // set group id on execution
        fsf_unix_sticky,    // S_ISVTX, will require super-user rights to alter it
        
        // may be set or unset by either the owner of a file or the super-user:
        fsf_uf_nodump,      // Do not dump the file
        fsf_uf_immutable,   // The file may not be changed
        fsf_uf_append,      // The file may only be appended to
        fsf_uf_opaque,      // The directory is opaque when viewed through a union stack
        fsf_uf_hidden,      // The file or directory is not intended to be displayed to the user
        fsf_uf_compressed,  // hfs-compression set on
        fsf_uf_tracked,     // document file is tracked
        
        // may only be set or unset by the super-user:
        fsf_sf_archived,    // The file has been archived.
        fsf_sf_immutable,   // The file may not be changed.
        fsf_sf_append,      // The file may only be appended to.

        fsf_totalcount
    };
    
    vector<tribool>                             flags = vector<tribool>(fsf_totalcount, indeterminate);
    shared_ptr<const vector<VFSListingItem>>    items;
    optional<uid_t>                             uid;
    optional<gid_t>                             gid;
    optional<time_t>                            atime;
    optional<time_t>                            mtime;
    optional<time_t>                            ctime;
    optional<time_t>                            btime;
    bool                                        process_subdirs = false;
};
