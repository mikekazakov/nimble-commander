//
//  filesysattr.h
//  Directories
//
//  Created by Michael G. Kazakov on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

class PanelData;

class FileSysAttrAlterCommand
{
public:
    enum fsflags
    {
        fsf_unix_usr_r=0, // R for owner
        fsf_unix_usr_w=1, // W for owner
        fsf_unix_usr_x=2, // X for owner
        fsf_unix_grp_r=3, // R for group
        fsf_unix_grp_w=4, // W for group
        fsf_unix_grp_x=5, // X for group
        fsf_unix_oth_r=6, // R for other
        fsf_unix_oth_w=7, // W for other
        fsf_unix_oth_x=8, // X for other
        fsf_unix_sticky=9,// S_ISVTX, will require super-user rights to alter it
        fsf_uf_nodump=10, // Do not dump the file
        
        // may be set or unset by either the owner of a file or the super-user:
        fsf_uf_immutable=11,// The file may not be changed
        fsf_uf_append=12,   // The file may only be appended to
        fsf_uf_opaque=13,   // The directory is opaque when viewed through a union stack
        fsf_uf_hidden=14,   // The file or directory is not intended to be displayed to the user
        
        // may only be set or unset by the super-user:
        fsf_sf_archived=15, // The file has been archived.
        fsf_sf_immutable=16,// The file may not be changed.
        fsf_sf_append=17,   // The file may only be appended to.

        fsf_totalcount
    };
    enum fsfcommands
    {
        fsf_clear,
        fsf_set
    };
    enum fsfstate
    {
        fsf_off,
        fsf_on,
        fsf_mixed
    };

    static void GetCommonFSFlagsState(const PanelData& _pd, fsfstate _state[fsf_totalcount]);
    static void GetCommonFSUIDAndGID(const PanelData& _pd,
                                     uid_t &_uid,
                                     bool &_has_common_uid,
                                     gid_t &_gid,
                                     bool &_has_common_gid);
};


