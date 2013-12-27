//
//  VFSHost.h
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <string>
#import <memory>

using namespace std;

#import "VFSError.h"
#import "chained_strings.h"

class VFSListing;
class VFSFile;

struct VFSStatFS
{
    uint64_t total_bytes;
    uint64_t free_bytes;
    uint64_t avail_bytes; // may be less than actuat free_bytes
    string volume_name;
};

class VFSHost : public enable_shared_from_this<VFSHost>
{
public:
    VFSHost(const char *_junction_path,         // junction path and parent can be nil
            shared_ptr<VFSHost> _parent);
    virtual ~VFSHost();
    
    enum {
        F_Default  = 0,
        F_NoFollow = 1 << 0, // do not follow symlinks when resolving item name
        F_NoDotDot = 1 << 1  // don't fetch dot-dot entry in directory listing
    };
    
    
    virtual bool IsWriteable() const;
    virtual bool IsWriteableAtPath(const char *_dir) const;
    
    virtual const char *FSTag() const;
    inline bool IsNativeFS() const { return strcmp(FSTag(), "native") == 0; }
    /**
     * returns a path of a filesystem root
     * it may be a filepath for archive or network address for remote filesystem
     * or even zero thing for special virtual filesystems
     */
    const char *JunctionPath() const;
    shared_ptr<VFSHost> Parent() const;
    
    
    
    virtual int StatFS(const char *_path, // path may be a file path, or directory path
                       VFSStatFS &_stat,
                       bool (^_cancel_checker)());
    
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             bool (^_cancel_checker)());
    
    virtual bool FindLastValidItem(const char *_orig_path,
                                   char *_valid_path,
                                   int _flags,
                                   bool (^_cancel_checker)());
    
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,
                                      bool (^_cancel_checker)());
    
    // IterateDirectoryListing will skip "." and ".." entries if they are present
    // do not rely on it to build a directory listing, it's for contents iteration
    virtual int IterateDirectoryListing(
                                    const char *_path,
                                    bool (^_handler)(struct dirent &_dirent) // return true for allowing iteration, false to stop it
                                    );
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> *_target,
                           bool (^_cancel_checker)());
    
    virtual int CalculateDirectoriesSizes(
                                        chained_strings _dirs,
                                        const string &_root_path, // relative to current host path
                                        bool (^_cancel_checker)(),
                                        void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size));
    
    virtual int Stat(const char *_path,
                     struct stat &_st,
                     int _flags,
                     bool (^_cancel_checker)());
    
    virtual int Unlink(const char *_path, bool (^_cancel_checker)());
    
    // return value 0 means error or unsupported for this VFS
    virtual unsigned long DirChangeObserve(const char *_path, void (^_handler)());
    virtual void StopDirChangeObserving(unsigned long _ticket);
    
    inline shared_ptr<VFSHost> SharedPtr() { return shared_from_this(); }
    inline shared_ptr<const VFSHost> SharedPtr() const { return shared_from_this(); }
private:
    string m_JunctionPath;         // path in Parent VFS, relative to it's root
    shared_ptr<VFSHost> m_Parent;
    
    // forbid copying
    VFSHost(const VFSHost& _r) = delete;
    void operator=(const VFSHost& _r) = delete;
};
