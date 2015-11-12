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

class PanelData;

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
    enum fstmvals { // we give no abitily to view and edit msec and nsec. but who cares?
        fstm_year=0,
        fstm_mon=1,
        fstm_day=2,
        fstm_hour=3,
        fstm_min=4,
        fstm_sec=5,
        fstm_totalcount
    };

    tribool  flags[fsf_totalcount];
    // todo: switch to optionals:
    bool     set_uid;
    uid_t    uid;
    bool     set_gid;
    gid_t    gid;
    bool     set_atime;
    time_t   atime;
    bool     set_mtime;
    time_t   mtime;
    bool     set_ctime;
    time_t   ctime;
    bool     set_btime;
    time_t   btime;
    bool     process_subdirs;
    chained_strings files;
    string   root_path;
    shared_ptr<const vector<VFSListingItem>> items;
    

    // section that operates with selected panel items
//    static void GetCommonFSFlagsState(const PanelData& _pd,
//                                      tribool _state[fsf_totalcount]);
    static void GetCommonFSFlagsState(const vector<VFSListingItem>& _items,
                                      tribool _state[fsf_totalcount]);
    
//    
//    static void GetCommonFSUIDAndGID(const PanelData& _pd,
//                                     uid_t &_uid,
//                                     bool &_has_common_uid,
//                                     gid_t &_gid,
//                                     bool &_has_common_gid);

    static void GetCommonFSUIDAndGID(const vector<VFSListingItem>& _items,
                                     uid_t &_uid,
                                     bool &_has_common_uid,
                                     gid_t &_gid,
                                     bool &_has_common_gid);
    
//    static void GetCommonFSTimes(const PanelData& _pd,
//                                 int _atimes[fstm_totalcount],
//                                 int _mtimes[fstm_totalcount],
//                                 int _ctimes[fstm_totalcount],
//                                 int _btimes[fstm_totalcount]
//                                 ); // -1 value mean there's no common time
    
//    static void GetCommonFSTimes(const PanelData& _pd,
//                                 time_t &_atime, bool &_has_common_atime,
//                                 time_t &_mtime, bool &_has_common_mtime,
//                                 time_t &_ctime, bool &_has_common_ctime,
//                                 time_t &_btime, bool &_has_common_btime);
    
    static void GetCommonFSTimes(const vector<VFSListingItem>& _items,
                                 time_t &_atime, bool &_has_common_atime,
                                 time_t &_mtime, bool &_has_common_mtime,
                                 time_t &_ctime, bool &_has_common_ctime,
                                 time_t &_btime, bool &_has_common_btime);
};


