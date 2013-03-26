//
//  filesysattr.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "filesysattr.h"
#include "PanelData.h"
#include <sys/types.h>

void FileSysAttrAlterCommand::GetCommonFSFlagsState(const PanelData& _pd, fsfstate _st[fsf_totalcount])
{
    for(int i =0; i < fsf_totalcount; ++i) _st[i] = fsf_mixed;
    bool first = true;
    mode_t first_mode=0;
    uint32_t first_flags=0;
    
    const auto &entries = _pd.DirectoryEntries();
    auto i = entries.begin(), e = entries.end();
    for(;i!=e;++i)
    {
        const auto &item = *i;
        if(item.cf_isselected())
        {
            if(first)
            { // set values as first found entry
                _st[fsf_unix_usr_r] = item.unix_mode & S_IRUSR ? fsf_on : fsf_off;
                _st[fsf_unix_usr_w] = item.unix_mode & S_IWUSR ? fsf_on : fsf_off;
                _st[fsf_unix_usr_x] = item.unix_mode & S_IXUSR ? fsf_on : fsf_off;
                _st[fsf_unix_grp_r] = item.unix_mode & S_IRGRP ? fsf_on : fsf_off;
                _st[fsf_unix_grp_w] = item.unix_mode & S_IWGRP ? fsf_on : fsf_off;
                _st[fsf_unix_grp_x] = item.unix_mode & S_IXGRP ? fsf_on : fsf_off;
                _st[fsf_unix_oth_r] = item.unix_mode & S_IROTH ? fsf_on : fsf_off;
                _st[fsf_unix_oth_w] = item.unix_mode & S_IWOTH ? fsf_on : fsf_off;
                _st[fsf_unix_oth_x] = item.unix_mode & S_IXOTH ? fsf_on : fsf_off;
                _st[fsf_unix_sticky]= item.unix_mode & S_ISVTX ? fsf_on : fsf_off;
                _st[fsf_uf_nodump]    = item.unix_flags & UF_NODUMP    ? fsf_on : fsf_off;
                _st[fsf_uf_immutable] = item.unix_flags & UF_IMMUTABLE ? fsf_on : fsf_off;
                _st[fsf_uf_append]    = item.unix_flags & UF_APPEND    ? fsf_on : fsf_off;
                _st[fsf_uf_opaque]    = item.unix_flags & UF_OPAQUE    ? fsf_on : fsf_off;
                _st[fsf_uf_hidden]    = item.unix_flags & UF_HIDDEN    ? fsf_on : fsf_off;
                _st[fsf_sf_archived]  = item.unix_flags & SF_ARCHIVED  ? fsf_on : fsf_off;
                _st[fsf_sf_immutable] = item.unix_flags & SF_IMMUTABLE ? fsf_on : fsf_off;
                _st[fsf_sf_append]    = item.unix_flags & SF_APPEND    ? fsf_on : fsf_off;
                first = false;
                first_mode = item.unix_mode;
                first_flags = item.unix_flags;
            }
            else
            { // adjust values if current entry is not conforming
                if((first_mode ^ item.unix_mode) & S_IRUSR) _st[fsf_unix_usr_r] = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_IWUSR) _st[fsf_unix_usr_w] = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_IXUSR) _st[fsf_unix_usr_x] = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_IRGRP) _st[fsf_unix_grp_r] = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_IWGRP) _st[fsf_unix_grp_w] = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_IXGRP) _st[fsf_unix_grp_x] = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_IROTH) _st[fsf_unix_oth_r] = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_IWOTH) _st[fsf_unix_oth_w] = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_IXOTH) _st[fsf_unix_oth_x] = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_ISVTX) _st[fsf_unix_sticky]= fsf_mixed;
                if((first_flags ^ item.unix_flags) & UF_NODUMP)     _st[fsf_uf_nodump]= fsf_mixed;
                if((first_flags ^ item.unix_flags) & UF_IMMUTABLE)  _st[fsf_uf_immutable]= fsf_mixed;
                if((first_flags ^ item.unix_flags) & UF_APPEND)     _st[fsf_uf_append]= fsf_mixed;
                if((first_flags ^ item.unix_flags) & UF_OPAQUE)     _st[fsf_uf_opaque]= fsf_mixed;
                if((first_flags ^ item.unix_flags) & UF_HIDDEN)     _st[fsf_uf_hidden]= fsf_mixed;
                if((first_flags ^ item.unix_flags) & SF_ARCHIVED)   _st[fsf_sf_archived]= fsf_mixed;
                if((first_flags ^ item.unix_flags) & SF_IMMUTABLE)  _st[fsf_sf_immutable]= fsf_mixed;
                if((first_flags ^ item.unix_flags) & SF_APPEND)     _st[fsf_sf_append]= fsf_mixed;
            }
        }
    }
}

void FileSysAttrAlterCommand::GetCommonFSUIDAndGID(const PanelData& _pd,
                                 uid_t &_uid,
                                 bool &_has_common_uid,
                                 gid_t &_gid,
                                 bool &_has_common_gid)
{
    bool first = true, common_uid = true, common_gid = true;
    uid_t first_uid=-1;
    gid_t first_gid=-1;
    const auto &entries = _pd.DirectoryEntries();
    auto i = entries.begin(), e = entries.end();
    for(;i!=e;++i)
    {
        const auto &item = *i;
        if(item.cf_isselected())
        {
            if(first)
            {
                first = false;
                first_uid = item.unix_uid;
                first_gid = item.unix_gid;
            }
            else
            {
                if(item.unix_uid != first_uid) common_uid = false;
                if(item.unix_gid != first_gid) common_gid = false;
            }
        }
    }
    _has_common_uid = common_uid;
    _uid = common_uid ? first_uid : -1;
    _gid = common_gid ? first_gid : -1;
}
