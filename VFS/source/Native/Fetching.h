// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

class PosixIOInterface;

namespace nc::vfs::native {

class Fetching
{
public:

    struct CallbackParams
    {
        const char*         filename = nullptr;
        time_t              crt_time = 0;
        time_t              mod_time = 0;
        time_t              chg_time = 0;
        time_t              acc_time = 0;
        time_t              add_time = 0; // may be -1 if absent
        uid_t               uid = 0;
        gid_t               gid = 0;
        mode_t              mode = 0;
        dev_t               dev = 0;
        uint64_t            inode = 0;
        uint32_t            flags = 0;
        int64_t             size = 0; // will be -1 if absent
    };
    
    using Callback = function<void(const CallbackParams &_params)>;

    /**
     * will not set .filename field.
     * Initially, tries to open() path and use fgetattrlist() to retrieve the data.
     * In case of symlinks falls back to lstat() call.
     * returns 0 on success or errno value on error
     */
    static int ReadSingleEntryAttributesByPath(PosixIOInterface &_io,
                                               const char *_path,
                                               const Callback &_cb);
    
    /** assuming this will be called when Admin Mode is on
     * returns 0 on success or errno value on error
     */
    static int ReadDirAttributesStat(
                                     const int _dir_fd,
                                     const char *_dir_path,
                                     const function<void(int _fetched_now)> &_cb_fetch,
                                     const Callback &_cb_param);
    
    /** 
     * the most performant way to fetch data
     * returns 0 on success or errno value on error
     */
    static int ReadDirAttributesBulk(
                                     const int _dir_fd,
                                     const function<void(int _fetched_now)> &_cb_fetch,
                                     const Callback &_cb_param);
    
    /**
     * returns VFSError or entries count.
     */
    static int CountDirEntries( const int _dir_fd );
};

}
