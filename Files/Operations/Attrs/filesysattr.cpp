//
//  filesysattr.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <sys/types.h>
#include <sys/stat.h>
#include "filesysattr.h"

//void FileSysAttrAlterCommand::GetCommonFSFlagsState(const PanelData& _pd, tribool _st[fsf_totalcount])
//{
//    for(int i =0; i < fsf_totalcount; ++i) _st[i] = indeterminate;
//    bool first = true;
//    mode_t first_mode=0;
//    uint32_t first_flags=0;
//    
////    const auto &entries = _pd.DirectoryEntries();
////    auto i = entries.begin(), e = entries.end();
////    for(;i!=e;++i)
//    for(const auto &item: _pd.Listing())
//    {
////        const auto &item = *i;
//        if(item.CFIsSelected())
//        {
//            if(first)
//            { // set values as first found entry
//                _st[fsf_unix_usr_r] = item.UnixMode() & S_IRUSR;
//                _st[fsf_unix_usr_w] = item.UnixMode() & S_IWUSR;
//                _st[fsf_unix_usr_x] = item.UnixMode() & S_IXUSR;
//                _st[fsf_unix_grp_r] = item.UnixMode() & S_IRGRP;
//                _st[fsf_unix_grp_w] = item.UnixMode() & S_IWGRP;
//                _st[fsf_unix_grp_x] = item.UnixMode() & S_IXGRP;
//                _st[fsf_unix_oth_r] = item.UnixMode() & S_IROTH;
//                _st[fsf_unix_oth_w] = item.UnixMode() & S_IWOTH;
//                _st[fsf_unix_oth_x] = item.UnixMode() & S_IXOTH;
//                _st[fsf_unix_suid]  = item.UnixMode() & S_ISUID;
//                _st[fsf_unix_sgid]  = item.UnixMode() & S_ISGID;
//                _st[fsf_unix_sticky]= item.UnixMode() & S_ISVTX;
//                _st[fsf_uf_nodump]    = item.UnixFlags() & UF_NODUMP;
//                _st[fsf_uf_immutable] = item.UnixFlags() & UF_IMMUTABLE;
//                _st[fsf_uf_append]    = item.UnixFlags() & UF_APPEND;
//                _st[fsf_uf_opaque]    = item.UnixFlags() & UF_OPAQUE;
//                _st[fsf_uf_hidden]    = item.UnixFlags() & UF_HIDDEN;
//                _st[fsf_uf_compressed]= item.UnixFlags() & UF_COMPRESSED;
//                _st[fsf_uf_tracked]   = item.UnixFlags() & UF_TRACKED;
//                _st[fsf_sf_archived]  = item.UnixFlags() & SF_ARCHIVED;
//                _st[fsf_sf_immutable] = item.UnixFlags() & SF_IMMUTABLE;
//                _st[fsf_sf_append]    = item.UnixFlags() & SF_APPEND;
//                first = false;
//                first_mode = item.UnixMode();
//                first_flags = item.UnixFlags();
//            }
//            else
//            { // adjust values if current entry is not conforming
//                if((first_mode ^ item.UnixMode()) & S_IRUSR) _st[fsf_unix_usr_r] = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_IWUSR) _st[fsf_unix_usr_w] = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_IXUSR) _st[fsf_unix_usr_x] = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_IRGRP) _st[fsf_unix_grp_r] = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_IWGRP) _st[fsf_unix_grp_w] = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_IXGRP) _st[fsf_unix_grp_x] = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_IROTH) _st[fsf_unix_oth_r] = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_IWOTH) _st[fsf_unix_oth_w] = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_IXOTH) _st[fsf_unix_oth_x] = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_ISUID) _st[fsf_unix_suid]  = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_ISGID) _st[fsf_unix_sgid]  = indeterminate;
//                if((first_mode ^ item.UnixMode()) & S_ISVTX) _st[fsf_unix_sticky]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & UF_NODUMP)     _st[fsf_uf_nodump]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & UF_IMMUTABLE)  _st[fsf_uf_immutable]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & UF_APPEND)     _st[fsf_uf_append]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & UF_OPAQUE)     _st[fsf_uf_opaque]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & UF_HIDDEN)     _st[fsf_uf_hidden]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & UF_COMPRESSED) _st[fsf_uf_compressed]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & UF_TRACKED)    _st[fsf_uf_tracked]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & SF_ARCHIVED)   _st[fsf_sf_archived]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & SF_IMMUTABLE)  _st[fsf_sf_immutable]= indeterminate;
//                if((first_flags ^ item.UnixFlags()) & SF_APPEND)     _st[fsf_sf_append]= indeterminate;
//                
//
//            }
//        }
//    }
//}

template <class _InputIterator, class _Predicate>
static tribool
all_eq_onoff(_InputIterator __first, _InputIterator __last, _Predicate __pred)
{
    tribool firstval = indeterminate;
    if( __first != __last )
        firstval = bool(__pred(*__first));
    
    for (; __first != __last; ++__first)
        if ( bool(__pred(*__first)) != firstval )
            return indeterminate;
    return firstval;
}

void FileSysAttrAlterCommand::GetCommonFSFlagsState(const vector<VFSListingItem>& _items, tribool _state[fsf_totalcount])
{
    // not the most efficient way since we call UnixMode and UnixFlag a lot more than actually can, but it shouldn't be a bottleneck anytime
    _state[fsf_unix_usr_r]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IRUSR;          });
    _state[fsf_unix_usr_w]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IWUSR;          });
    _state[fsf_unix_usr_x]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IXUSR;          });
    _state[fsf_unix_grp_r]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IRGRP;          });
    _state[fsf_unix_grp_w]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IWGRP;          });
    _state[fsf_unix_grp_x]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IXGRP;          });
    _state[fsf_unix_oth_r]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IROTH;          });
    _state[fsf_unix_oth_w]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IWOTH;          });
    _state[fsf_unix_oth_x]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_IXOTH;          });
    _state[fsf_unix_suid]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_ISUID;          });
    _state[fsf_unix_sgid]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_ISGID;          });
    _state[fsf_unix_sticky]     = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixMode()     & S_ISVTX;          });
    _state[fsf_uf_nodump]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_NODUMP;        });
    _state[fsf_uf_immutable]    = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_IMMUTABLE;     });
    _state[fsf_uf_append]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_APPEND;        });
    _state[fsf_uf_opaque]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_OPAQUE;        });
    _state[fsf_uf_hidden]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_HIDDEN;        });
    _state[fsf_uf_compressed]   = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_COMPRESSED;    });
    _state[fsf_uf_tracked]      = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & UF_TRACKED;       });
    _state[fsf_sf_archived]     = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & SF_ARCHIVED;      });
    _state[fsf_sf_immutable]    = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & SF_IMMUTABLE;     });
    _state[fsf_sf_append]       = all_eq_onoff(begin(_items), end(_items), [](auto &i){ return i.UnixFlags()    & SF_APPEND;        });
}

//void FileSysAttrAlterCommand::GetCommonFSUIDAndGID(const PanelData& _pd,
//                                 uid_t &_uid,
//                                 bool &_has_common_uid,
//                                 gid_t &_gid,
//                                 bool &_has_common_gid)
//{
//    bool first = true;
//    _has_common_uid = false;
//    _has_common_gid = false;
//    for(const auto &i : _pd.Listing())
//    {
//        if(i.CFIsSelected())
//        {
//            if(first)
//            {
//                first = false;
//                _uid = i.UnixUID();
//                _gid = i.UnixGID();
//                _has_common_uid = true;
//                _has_common_gid = true;
//            }
//            else
//            {
//                if(i.UnixUID() != _uid) _has_common_uid = false;
//                if(i.UnixGID() != _gid) _has_common_gid = false;
//            }
//        }
//    }
//}

void FileSysAttrAlterCommand::GetCommonFSUIDAndGID(const vector<VFSListingItem>& _items,
                                                   uid_t &_uid,
                                                   bool &_has_common_uid,
                                                   gid_t &_gid,
                                                   bool &_has_common_gid)
{
    _has_common_uid = all_of(begin(_items), end(_items), [&](auto &i){ return i.UnixUID() == _items.front().UnixUID(); });
    if( _has_common_uid )
        _uid = _items.front().UnixUID();

    _has_common_gid = all_of(begin(_items), end(_items), [&](auto &i){ return i.UnixGID() == _items.front().UnixGID(); });
    if( _has_common_gid )
        _gid = _items.front().UnixGID();
}

//void FileSysAttrAlterCommand::GetCommonFSTimes(const PanelData& _pd,
//                                               int _atimes[fstm_totalcount],
//                                               int _mtimes[fstm_totalcount],
//                                               int _ctimes[fstm_totalcount],
//                                               int _btimes[fstm_totalcount]
//                                               )
//{
//    bool first = true;
//    time_t t_atime, t_mtime, t_ctime, t_btime;
//    struct tm atime, mtime, ctime, btime;
//    struct tm cur_atime, cur_mtime, cur_ctime, cur_btime;
//
//    for(int i = 0; i < fstm_totalcount; ++i)
//        _atimes[i] = _mtimes[i] = _ctimes[i] = _btimes[i] = -1;
//
//    for(const auto &i : _pd.Listing())
//    {
//        if(i.CFIsSelected())
//        {
//            t_atime = i.ATime();
//            t_mtime = i.MTime();
//            t_ctime = i.CTime();
//            t_btime = i.BTime();
//            
//            if(first)
//            {
//                localtime_r(&t_atime, &atime);
//                _atimes[fstm_year] = atime.tm_year + 1900;
//                _atimes[fstm_mon]  = atime.tm_mon + 1;
//                _atimes[fstm_day]  = atime.tm_mday;
//                _atimes[fstm_hour] = atime.tm_hour;
//                _atimes[fstm_min]  = atime.tm_min;
//                _atimes[fstm_sec]  = atime.tm_sec;
//                
//                localtime_r(&t_mtime, &mtime);
//                _mtimes[fstm_year] = mtime.tm_year + 1900;
//                _mtimes[fstm_mon]  = mtime.tm_mon + 1;
//                _mtimes[fstm_day]  = mtime.tm_mday;
//                _mtimes[fstm_hour] = mtime.tm_hour;
//                _mtimes[fstm_min]  = mtime.tm_min;
//                _mtimes[fstm_sec]  = mtime.tm_sec;
//
//                localtime_r(&t_ctime, &ctime);
//                _ctimes[fstm_year] = ctime.tm_year + 1900;
//                _ctimes[fstm_mon]  = ctime.tm_mon + 1;
//                _ctimes[fstm_day]  = ctime.tm_mday;
//                _ctimes[fstm_hour] = ctime.tm_hour;
//                _ctimes[fstm_min]  = ctime.tm_min;
//                _ctimes[fstm_sec]  = ctime.tm_sec;
//
//                localtime_r(&t_btime, &btime);
//                _btimes[fstm_year] = btime.tm_year + 1900;
//                _btimes[fstm_mon]  = btime.tm_mon + 1;
//                _btimes[fstm_day]  = btime.tm_mday;
//                _btimes[fstm_hour] = btime.tm_hour;
//                _btimes[fstm_min]  = btime.tm_min;
//                _btimes[fstm_sec]  = btime.tm_sec;
//
//                first = false;
//            }
//            else
//            {
//                localtime_r(&t_atime, &cur_atime);
//                localtime_r(&t_mtime, &cur_mtime);
//                localtime_r(&t_ctime, &cur_ctime);
//                localtime_r(&t_btime, &cur_btime);
//                
//                if(cur_atime.tm_year != atime.tm_year) _atimes[fstm_year] = -1;
//                if(cur_atime.tm_mon  != atime.tm_mon)  _atimes[fstm_mon]  = -1;
//                if(cur_atime.tm_mday != atime.tm_mday) _atimes[fstm_day]  = -1;
//                if(cur_atime.tm_hour != atime.tm_hour) _atimes[fstm_hour] = -1;
//                if(cur_atime.tm_min  != atime.tm_min)  _atimes[fstm_min]  = -1;
//                if(cur_atime.tm_sec  != atime.tm_sec)  _atimes[fstm_sec]  = -1;
//                if(cur_mtime.tm_year != mtime.tm_year) _mtimes[fstm_year] = -1;
//                if(cur_mtime.tm_mon  != mtime.tm_mon)  _mtimes[fstm_mon]  = -1;
//                if(cur_mtime.tm_mday != mtime.tm_mday) _mtimes[fstm_day]  = -1;
//                if(cur_mtime.tm_hour != mtime.tm_hour) _mtimes[fstm_hour] = -1;
//                if(cur_mtime.tm_min  != mtime.tm_min)  _mtimes[fstm_min]  = -1;
//                if(cur_mtime.tm_sec  != mtime.tm_sec)  _mtimes[fstm_sec]  = -1;
//                if(cur_ctime.tm_year != ctime.tm_year) _ctimes[fstm_year] = -1;
//                if(cur_ctime.tm_mon  != ctime.tm_mon)  _ctimes[fstm_mon]  = -1;
//                if(cur_ctime.tm_mday != ctime.tm_mday) _ctimes[fstm_day]  = -1;
//                if(cur_ctime.tm_hour != ctime.tm_hour) _ctimes[fstm_hour] = -1;
//                if(cur_ctime.tm_min  != ctime.tm_min)  _ctimes[fstm_min]  = -1;
//                if(cur_ctime.tm_sec  != ctime.tm_sec)  _ctimes[fstm_sec]  = -1;
//                if(cur_btime.tm_year != btime.tm_year) _btimes[fstm_year] = -1;
//                if(cur_btime.tm_mon  != btime.tm_mon)  _btimes[fstm_mon]  = -1;
//                if(cur_btime.tm_mday != btime.tm_mday) _btimes[fstm_day]  = -1;
//                if(cur_btime.tm_hour != btime.tm_hour) _btimes[fstm_hour] = -1;
//                if(cur_btime.tm_min  != btime.tm_min)  _btimes[fstm_min]  = -1;
//                if(cur_btime.tm_sec  != btime.tm_sec)  _btimes[fstm_sec]  = -1;
//            }
//        }
//    }
//}

//void FileSysAttrAlterCommand::GetCommonFSTimes(const PanelData& _pd,
//                             time_t &_atime, bool &_has_common_atime,
//                             time_t &_mtime, bool &_has_common_mtime,
//                             time_t &_ctime, bool &_has_common_ctime,
//                             time_t &_btime, bool &_has_common_btime)
//{
//    bool first = true;
//    _has_common_atime = _has_common_mtime = _has_common_ctime = _has_common_btime = false;    
//    for(const auto &i : _pd.Listing())
//        if(i.CFIsSelected())
//        {
//            if(first)
//            {
//                _has_common_atime = _has_common_mtime = _has_common_ctime = _has_common_btime = true;
//                _atime = i.ATime();
//                _mtime = i.MTime();
//                _ctime = i.CTime();
//                _btime = i.BTime();
//                first = false;
//            }
//            else
//            {
//                if(_atime != i.ATime()) _has_common_atime = false;
//                if(_mtime != i.MTime()) _has_common_mtime = false;
//                if(_ctime != i.CTime()) _has_common_ctime = false;
//                if(_btime != i.BTime()) _has_common_btime = false;
//            }
//        }
//}

void FileSysAttrAlterCommand::GetCommonFSTimes(const vector<VFSListingItem>& _items,
                                               time_t &_atime, bool &_has_common_atime,
                                               time_t &_mtime, bool &_has_common_mtime,
                                               time_t &_ctime, bool &_has_common_ctime,
                                               time_t &_btime, bool &_has_common_btime)
{
    _has_common_atime = all_of(begin(_items), end(_items), [&](auto &i){ return i.ATime() == _items.front().ATime(); });
    if( _has_common_atime )
        _atime = _items.front().ATime();
    
    _has_common_mtime = all_of(begin(_items), end(_items), [&](auto &i){ return i.MTime() == _items.front().MTime(); });
    if( _has_common_mtime )
        _mtime = _items.front().MTime();
    
    _has_common_ctime = all_of(begin(_items), end(_items), [&](auto &i){ return i.CTime() == _items.front().CTime(); });
    if( _has_common_ctime )
        _ctime = _items.front().CTime();
    
    _has_common_btime = all_of(begin(_items), end(_items), [&](auto &i){ return i.BTime() == _items.front().BTime(); });
    if( _has_common_btime )
        _btime = _items.front().BTime();
}
