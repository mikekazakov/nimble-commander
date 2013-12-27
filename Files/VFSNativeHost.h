//
//  VFSNativeHost.h
//  Files
//
//  Created by Michael G. Kazakov on 26.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSHost.h"

class VFSNativeHost : public VFSHost
{
public:
    VFSNativeHost();
    
    virtual const char *FSTag() const override;
    
    virtual bool IsWriteable() const override;
    virtual bool IsWriteableAtPath(const char *_dir) const override;
    
    virtual bool IsDirectory(const char *_path,
                             int _flags,
                             bool (^_cancel_checker)()) override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, bool (^_cancel_checker)()) override;    
    
    virtual int Stat(const char *_path, struct stat &_st, int _flags, bool (^_cancel_checker)()) override;
    
    virtual bool FindLastValidItem(const char *_orig_path,
                                   char *_valid_path,
                                   int _flags,
                                   bool (^_cancel_checker)()) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,                                      
                                      bool (^_cancel_checker)()) override;
    
    virtual int IterateDirectoryListing(const char *_path, bool (^_handler)(struct dirent &_dirent)) override;

    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> *_target,
                           bool (^_cancel_checker)()) override;
    
    virtual unsigned long DirChangeObserve(const char *_path, void (^_handler)()) override;
    virtual void StopDirChangeObserving(unsigned long _ticket) override;
    
    virtual int CalculateDirectoriesSizes(
                                        chained_strings _dirs,
                                        const string &_root_path, // relative to current host path
                                        bool (^_cancel_checker)(),
                                        void (^_completion_handler)(const char* _dir_sh_name, uint64_t _size)
                                        ) override;
    
    virtual int Unlink(const char *_path, bool (^_cancel_checker)()) override;
    
    shared_ptr<const VFSNativeHost> SharedPtr() const {return static_pointer_cast<const VFSNativeHost>(VFSHost::SharedPtr());}
    shared_ptr<VFSNativeHost> SharedPtr() {return static_pointer_cast<VFSNativeHost>(VFSHost::SharedPtr());}
    static shared_ptr<VFSNativeHost> SharedHost();
    
private:
    
    

};
