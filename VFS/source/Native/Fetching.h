#pragma once

class PosixIOInterface;

class VFSNativeFetching
{
public:

    struct CallbackParams
    {
        const char*         filename;
        time_t              crt_time;
        time_t              mod_time;
        time_t              chg_time;
        time_t              acc_time;
        time_t              add_time; // may be -1 if absent
        uid_t               uid;
        gid_t               gid;
        mode_t              mode;
        dev_t               dev;
        uint64_t            inode;
        uint32_t            flags;
        int64_t             size; // will be -1 if absent
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

