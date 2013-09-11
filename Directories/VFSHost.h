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

#import "VFSError.h"
#import "FlexChainedStringsChunk.h"

class VFSListing;
class VFSFile;

class VFSHost : public std::enable_shared_from_this<VFSHost>
{
public:
    VFSHost(const char *_junction_path,         // junction path and parent can be nil
            std::shared_ptr<VFSHost> _parent);
    virtual ~VFSHost();
    
    enum {
        F_NoFollow = 1 // do not follow symlinks when resolving item name
        
    };
    
    virtual bool IsWriteable() const;
    // TODO: IsWriteableAtPath
    
    virtual const char *FSTag() const;
    inline bool IsNativeFS() const { return strcmp(FSTag(), "native") == 0; }
    
    const char *JunctionPath() const;
    std::shared_ptr<VFSHost> Parent() const;
    
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             bool (^_cancel_checker)());
    
    virtual bool FindLastValidItem(const char *_orig_path,
                                   char *_valid_path,
                                   int _flags,
                                   bool (^_cancel_checker)());
    
    virtual int FetchDirectoryListing(const char *_path,
                                      std::shared_ptr<VFSListing> *_target,
                                      bool (^_cancel_checker)());
    
    // IterateDirectoryListing will skip "." and ".." entries if they are present
    // do not rely on it to build a directory listing, it's for contents iteration
    virtual int IterateDirectoryListing(
                                    const char *_path,
                                    bool (^_handler)(struct dirent &_dirent) // return true for allowing iteration, false to stop it
                                    );
    
    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> *_target,
                           bool (^_cancel_checker)());
    
    virtual int CalculateDirectoriesSizes(
                                        FlexChainedStringsChunk *_dirs, // transfered ownership
                                        const std::string &_root_path, // relative to current host path
                                        bool (^_cancel_checker)(),
                                        void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size));
    virtual int CalculateDirectoryDotDotSize( // will pass ".." as _dir_sh_name upon completion
                                          const std::string &_root_path, // relative to current host path
                                          bool (^_cancel_checker)(),
                                          void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size));
    
    virtual int Stat(const char *_path,
                     struct stat &_st,
                     int _flags,
                     bool (^_cancel_checker)());
    
    // return value 0 means error or unsupported for this VFS
    virtual unsigned long DirChangeObserve(const char *_path, void (^_handler)());
    virtual void StopDirChangeObserving(unsigned long _ticket);
    
    inline std::shared_ptr<VFSHost> SharedPtr() { return shared_from_this(); }
    inline std::shared_ptr<const VFSHost> SharedPtr() const { return shared_from_this(); }
private:
    std::string m_JunctionPath;         // path in Parent VFS, relative to it's root
    std::shared_ptr<VFSHost> m_Parent;
    
    // forbid copying
    VFSHost(const VFSHost& _r) = delete;
    void operator=(const VFSHost& _r) = delete;
};
