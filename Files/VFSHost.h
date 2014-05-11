//
//  VFSHost.h
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import <sys/stat.h>
#import "VFSError.h"
#import "chained_strings.h"

class VFSListing;
class VFSFile;

struct VFSStatFS
{
    uint64_t total_bytes = 0;
    uint64_t free_bytes  = 0;
    uint64_t avail_bytes = 0; // may be less than actuat free_bytes
    string   volume_name;
    
    inline bool operator==(const VFSStatFS& _r) const
    {
        return total_bytes == _r.total_bytes &&
                free_bytes == _r.free_bytes  &&
               avail_bytes == _r.avail_bytes &&
               volume_name == _r.volume_name;
    }
    
    inline bool operator!=(const VFSStatFS& _r) const
    {
        return total_bytes != _r.total_bytes ||
                free_bytes != _r.free_bytes  ||
               avail_bytes != _r.avail_bytes ||
               volume_name != _r.volume_name;
    }
};

struct VFSDirEnt
{
    enum {
        Unknown     =  0, /* = DT_UNKNOWN */
        FIFO        =  1, /* = DT_FIFO    */
        Char        =  2, /* = DT_CHR     */
        Dir         =  4, /* = DT_DIR     */
        Block       =  6, /* = DT_BLK     */
        Reg         =  8, /* = DT_REG     */
        Link        = 10, /* = DT_LNK     */
        Socket      = 12, /* = DT_SOCK    */
        Whiteout    = 14  /* = DT_WHT     */
    };
    
    uint16_t    type;
    uint16_t    name_len;
    char        name[1024];
};

struct VFSStat
{
    uint64_t    size;   /* File size, in bytes */
    uint64_t    blocks; /* blocks allocated for file */
    uint64_t    inode;  /* File serial number */
    int32_t     dev;    /* ID of device containing file */
    int32_t     rdev;   /* Device ID (if special file) */
    uint32_t    uid;    /* User ID of the file */
    uint32_t    gid;    /* Group ID of the file */
    int32_t     blksize;/* Optimal blocksize for I/O */
    uint32_t	flags;  /* User defined flags for file */
    uint16_t    mode;   /* Mode of file */
    uint16_t    nlink;  /* Number of hard links */
	timespec    atime;  /* Time of last access */
	timespec    mtime;	/* Time of last data modification */
	timespec    ctime;	/* Time of last status change */
	timespec    btime;	/* Time of file creation(birth) */
    static void FromSysStat(const struct stat &_from, VFSStat &_to);
    static void ToSysStat(const VFSStat &_from, struct stat &_to);
};

class VFSHost : public enable_shared_from_this<VFSHost>
{
public:
    VFSHost(const char *_junction_path,         // junction path and parent can be nil
            shared_ptr<VFSHost> _parent);
    virtual ~VFSHost();
    
    enum {
        F_Default  = 0b0000,
        F_NoFollow = 0b0001, // do not follow symlinks when resolving item name
        F_NoDotDot = 0b0010  // don't fetch dot-dot entry in directory listing
    };
    
    
    virtual bool IsWriteable() const;
    virtual bool IsWriteableAtPath(const char *_dir) const;
    
    virtual const char *FSTag() const;
    virtual bool IsNativeFS() const { return false; }
    /**
     * Returns a path of a filesystem root.
     * It may be a filepath for archive or network address for remote filesystem
     * or even zero thing for special virtual filesystems.
     */
    const char *JunctionPath() const;
    shared_ptr<VFSHost> Parent() const;
    
    
    
    virtual int StatFS(const char *_path, // path may be a file path, or directory path
                       VFSStatFS &_stat,
                       bool (^_cancel_checker)());
    
    /**
     * Default implementation calls Stat() and then returns (st.st_mode & S_IFMT) == S_IFDIR.
     * On any errors returns false.
     */
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             bool (^_cancel_checker)());

    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,
                                      bool (^_cancel_checker)());
    
    /**
     * IterateDirectoryListing will skip "." and ".." entries if they are present.
     * Do not rely on it to build a directory listing, it's for contents iteration.
     */
    virtual int IterateDirectoryListing(
                                    const char *_path,
                                    bool (^_handler)(const VFSDirEnt &_dirent) // return true for allowing iteration, false to stop it
                                    );
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           bool (^_cancel_checker)());
    
    virtual int CreateDirectory(const char* _path,
                                bool (^_cancel_checker)()
                                );
    
    virtual int CalculateDirectoriesSizes(
                                        chained_strings _dirs,
                                        const char* _root_path,
                                        bool (^_cancel_checker)(),
                                        void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size));
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     bool (^_cancel_checker)());
    
    /**
     * Return zero upon succes, negative value on error.
     */
    virtual int ReadSymlink(const char *_symlink_path,
                            char *_buffer,
                            size_t _buffer_size,
                            bool (^_cancel_checker)());

    /**
     * Return zero upon succes, negative value on error.
     */
    virtual int CreateSymlink(const char *_symlink_path,
                              const char *_symlink_value,
                              bool (^_cancel_checker)());
    
    /**
     * Unlinkes(deletes) a file. Dont follow last symlink, in case of.
     * Don't delete a directories, similar to POSIX.
     */
    virtual int Unlink(const char *_path, bool (^_cancel_checker)());

    /**
     * Deletes and empty directory. Will fail on non-empty ones.
     */
    virtual int RemoveDirectory(const char *_path, bool (^_cancel_checker)());
    
    /**
     * Change the name of a file.
     */
    virtual int Rename(const char *_old_path, const char *_new_path, bool (^_cancel_checker)());
    
    /**
     * Adjust file node times. Any of timespec time pointers can be NULL, so they will be ignored.
     * NoFollow flag can be specified to alter symlink node itself.
     */
    virtual int SetTimes(const char *_path,
                         int _flags,
                         struct timespec *_birth_time,
                         struct timespec *_mod_time,
                         struct timespec *_chg_time,
                         struct timespec *_acc_time,
                         bool (^_cancel_checker)()
                         );
    
    // return value 0 means error or unsupported for this VFS
    virtual unsigned long DirChangeObserve(const char *_path, void (^_handler)());
    virtual void StopDirChangeObserving(unsigned long _ticket);
    
    virtual bool ShouldProduceThumbnails();
    
    virtual bool FindLastValidItem(const char *_orig_path,
                                   char *_valid_path,
                                   int _flags,
                                   bool (^_cancel_checker)());

    inline shared_ptr<VFSHost> SharedPtr() { return shared_from_this(); }
    inline shared_ptr<const VFSHost> SharedPtr() const { return shared_from_this(); }
#define VFS_DECLARE_SHARED_PTR(_cl)\
    shared_ptr<const _cl> SharedPtr() const {return static_pointer_cast<const _cl>(VFSHost::SharedPtr());}\
    shared_ptr<_cl> SharedPtr() {return static_pointer_cast<_cl>(VFSHost::SharedPtr());}

private:
    string m_JunctionPath;         // path in Parent VFS, relative to it's root
    shared_ptr<VFSHost> m_Parent;
    
    // forbid copying
    VFSHost(const VFSHost& _r) = delete;
    void operator=(const VFSHost& _r) = delete;
};

typedef shared_ptr<VFSHost> VFSHostPtr;
