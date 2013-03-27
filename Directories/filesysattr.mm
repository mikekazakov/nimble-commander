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
                _st[fsf_unix_suid]  = item.unix_mode & S_ISUID ? fsf_on : fsf_off;
                _st[fsf_unix_sgid]  = item.unix_mode & S_ISGID ? fsf_on : fsf_off;
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
                if((first_mode ^ item.unix_mode) & S_ISUID) _st[fsf_unix_suid]  = fsf_mixed;
                if((first_mode ^ item.unix_mode) & S_ISGID) _st[fsf_unix_sgid]  = fsf_mixed;
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
    bool first = true;
    _has_common_uid = false;
    _has_common_gid = false;
    for(const auto &i : _pd.DirectoryEntries())
    {
        if(i.cf_isselected())
        {
            if(first)
            {
                first = false;
                _uid = i.unix_uid;
                _gid = i.unix_gid;
                _has_common_uid = true;
                _has_common_gid = true;
            }
            else
            {
                if(i.unix_uid != _uid) _has_common_uid = false;
                if(i.unix_gid != _gid) _has_common_gid = false;
            }
        }
    }
}

void FileSysAttrAlterCommand::GetCommonFSTimes(const PanelData& _pd,
                                               int _atimes[fstm_totalcount],
                                               int _mtimes[fstm_totalcount],
                                               int _ctimes[fstm_totalcount],
                                               int _btimes[fstm_totalcount]
                                               )
{
    bool first = true; 
    struct tm atime, mtime, ctime, btime;
    struct tm cur_atime, cur_mtime, cur_ctime, cur_btime;

    for(int i = 0; i < fstm_totalcount; ++i)
        _atimes[i] = _mtimes[i] = _ctimes[i] = _btimes[i] = -1;

    for(const auto &i : _pd.DirectoryEntries())
    {
        if(i.cf_isselected())
        {
            if(first)
            {
                localtime_r(&i.atime, &atime);
                _atimes[fstm_year] = atime.tm_year + 1900;
                _atimes[fstm_mon]  = atime.tm_mon + 1;
                _atimes[fstm_day]  = atime.tm_mday;
                _atimes[fstm_hour] = atime.tm_hour;
                _atimes[fstm_min]  = atime.tm_min;
                _atimes[fstm_sec]  = atime.tm_sec;
                
                localtime_r(&i.mtime, &mtime);
                _mtimes[fstm_year] = mtime.tm_year + 1900;
                _mtimes[fstm_mon]  = mtime.tm_mon + 1;
                _mtimes[fstm_day]  = mtime.tm_mday;
                _mtimes[fstm_hour] = mtime.tm_hour;
                _mtimes[fstm_min]  = mtime.tm_min;
                _mtimes[fstm_sec]  = mtime.tm_sec;
                
                localtime_r(&i.ctime, &ctime);
                _ctimes[fstm_year] = ctime.tm_year + 1900;
                _ctimes[fstm_mon]  = ctime.tm_mon + 1;
                _ctimes[fstm_day]  = ctime.tm_mday;
                _ctimes[fstm_hour] = ctime.tm_hour;
                _ctimes[fstm_min]  = ctime.tm_min;
                _ctimes[fstm_sec]  = ctime.tm_sec;
                
                localtime_r(&i.btime, &btime);
                _btimes[fstm_year] = btime.tm_year + 1900;
                _btimes[fstm_mon]  = btime.tm_mon + 1;
                _btimes[fstm_day]  = btime.tm_mday;
                _btimes[fstm_hour] = btime.tm_hour;
                _btimes[fstm_min]  = btime.tm_min;
                _btimes[fstm_sec]  = btime.tm_sec;

                first = false;
            }
            else
            {
                localtime_r(&i.atime, &cur_atime);
                localtime_r(&i.mtime, &cur_mtime);
                localtime_r(&i.ctime, &cur_ctime);
                localtime_r(&i.btime, &cur_btime);
                
                if(cur_atime.tm_year != atime.tm_year) _atimes[fstm_year] = -1;
                if(cur_atime.tm_mon  != atime.tm_mon)  _atimes[fstm_mon]  = -1;
                if(cur_atime.tm_mday != atime.tm_mday) _atimes[fstm_day]  = -1;
                if(cur_atime.tm_hour != atime.tm_hour) _atimes[fstm_hour] = -1;
                if(cur_atime.tm_min  != atime.tm_min)  _atimes[fstm_min]  = -1;
                if(cur_atime.tm_sec  != atime.tm_sec)  _atimes[fstm_sec]  = -1;
                if(cur_mtime.tm_year != mtime.tm_year) _mtimes[fstm_year] = -1;
                if(cur_mtime.tm_mon  != mtime.tm_mon)  _mtimes[fstm_mon]  = -1;
                if(cur_mtime.tm_mday != mtime.tm_mday) _mtimes[fstm_day]  = -1;
                if(cur_mtime.tm_hour != mtime.tm_hour) _mtimes[fstm_hour] = -1;
                if(cur_mtime.tm_min  != mtime.tm_min)  _mtimes[fstm_min]  = -1;
                if(cur_mtime.tm_sec  != mtime.tm_sec)  _mtimes[fstm_sec]  = -1;
                if(cur_ctime.tm_year != ctime.tm_year) _ctimes[fstm_year] = -1;
                if(cur_ctime.tm_mon  != ctime.tm_mon)  _ctimes[fstm_mon]  = -1;
                if(cur_ctime.tm_mday != ctime.tm_mday) _ctimes[fstm_day]  = -1;
                if(cur_ctime.tm_hour != ctime.tm_hour) _ctimes[fstm_hour] = -1;
                if(cur_ctime.tm_min  != ctime.tm_min)  _ctimes[fstm_min]  = -1;
                if(cur_ctime.tm_sec  != ctime.tm_sec)  _ctimes[fstm_sec]  = -1;
                if(cur_btime.tm_year != btime.tm_year) _btimes[fstm_year] = -1;
                if(cur_btime.tm_mon  != btime.tm_mon)  _btimes[fstm_mon]  = -1;
                if(cur_btime.tm_mday != btime.tm_mday) _btimes[fstm_day]  = -1;
                if(cur_btime.tm_hour != btime.tm_hour) _btimes[fstm_hour] = -1;
                if(cur_btime.tm_min  != btime.tm_min)  _btimes[fstm_min]  = -1;
                if(cur_btime.tm_sec  != btime.tm_sec)  _btimes[fstm_sec]  = -1;
            }
        }
    }
}

void FileSysAttrAlterCommand::GetCommonFSTimes(const PanelData& _pd,
                             time_t &_atime, bool &_has_common_atime,
                             time_t &_mtime, bool &_has_common_mtime,
                             time_t &_ctime, bool &_has_common_ctime,
                             time_t &_btime, bool &_has_common_btime)
{
    bool first = true;
    _has_common_atime = _has_common_mtime = _has_common_ctime = _has_common_btime = false;    
    for(const auto &i : _pd.DirectoryEntries())
        if(i.cf_isselected())
        {
            if(first)
            {
                _has_common_atime = _has_common_mtime = _has_common_ctime = _has_common_btime = true;
                _atime = i.atime;
                _mtime = i.mtime;
                _ctime = i.ctime;
                _btime = i.btime;
                first = false;
            }
            else
            {
                if(_atime != i.atime) _has_common_atime = false;
                if(_mtime != i.mtime) _has_common_mtime = false;
                if(_ctime != i.ctime) _has_common_ctime = false;
                if(_btime != i.btime) _has_common_btime = false;
            }
        }
}
