//
//  filesysattr.h
//  Directories
//
//  Created by Michael G. Kazakov on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../../vfs/VFS.h"
#include "../../chained_strings.h"

struct FileSysAttrAlterCommand
{
    enum fsflags {
        fsf_unix_usr_r=0, // R for owner
        fsf_unix_usr_w, // W for owner
        fsf_unix_usr_x, // X for owner
        fsf_unix_grp_r, // R for group
        fsf_unix_grp_w, // W for group
        fsf_unix_grp_x, // X for group
        fsf_unix_oth_r, // R for other
        fsf_unix_oth_w, // W for other
        fsf_unix_oth_x, // X for other
        fsf_unix_suid,  // set user id on execution
        fsf_unix_sgid, // set group id on execution
        fsf_unix_sticky,//S_ISVTX, will require super-user rights to alter it
        fsf_uf_nodump, // Do not dump the file
        
        // may be set or unset by either the owner of a file or the super-user:
        fsf_uf_immutable,// The file may not be changed
        fsf_uf_append,   // The file may only be appended to
        fsf_uf_opaque,   // The directory is opaque when viewed through a union stack
        fsf_uf_hidden,   // The file or directory is not intended to be displayed to the user
        fsf_uf_compressed,// hfs-compression set on
        fsf_uf_tracked,  // document file is tracked
        
        // may only be set or unset by the super-user:
        fsf_sf_archived, // The file has been archived.
        fsf_sf_immutable,// The file may not be changed.
        fsf_sf_append,   // The file may only be appended to.

        
        
        fsf_totalcount
    };
    
    vector<tribool> flags = vector<tribool>(fsf_totalcount, indeterminate);

    // todo: switch to optionals:
    bool     set_uid = false;
    uid_t    uid;
    bool     set_gid = false;
    gid_t    gid;
    bool     set_atime = false;
    time_t   atime;
    bool     set_mtime = false;
    time_t   mtime;
    bool     set_ctime = false;
    time_t   ctime;
    bool     set_btime = false;
    time_t   btime;
    bool     process_subdirs = false;

    //    chained_strings files;
//    string   root_path;

    shared_ptr<const vector<VFSListingItem>> items;
    

    static void GetCommonFSFlagsState(const vector<VFSListingItem>& _items,
                                      tribool _state[fsf_totalcount]);

    static void GetCommonFSUIDAndGID(const vector<VFSListingItem>& _items,
                                     uid_t &_uid,
                                     bool &_has_common_uid,
                                     gid_t &_gid,
                                     bool &_has_common_gid);
    
    static void GetCommonFSTimes(const vector<VFSListingItem>& _items,
                                 time_t &_atime, bool &_has_common_atime,
                                 time_t &_mtime, bool &_has_common_mtime,
                                 time_t &_ctime, bool &_has_common_ctime,
                                 time_t &_btime, bool &_has_common_btime);
};
