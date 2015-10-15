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
    
    static const char *Tag;    
    virtual const char *FSTag() const override;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    virtual bool IsWriteable() const override;
    virtual bool IsWriteableAtPath(const char *_dir) const override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, VFSCancelChecker _cancel_checker) override;
    
    virtual int Stat(const char *_path, VFSStat &_st, int _flags, VFSCancelChecker _cancel_checker) override;
    
    virtual int FetchFlexibleListing(const char *_path,
                                     shared_ptr<VFSFlexibleListing> &_target,
                                     int _flags,
                                     VFSCancelChecker _cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path, function<bool(const VFSDirEnt &_dirent)> _handler) override;

    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           VFSCancelChecker _cancel_checker) override;
    
    virtual int CreateDirectory(const char* _path,
                                int _mode,
                                VFSCancelChecker _cancel_checker
                                ) override;
    
    virtual int RemoveDirectory(const char *_path, VFSCancelChecker _cancel_checker) override;
    
    virtual bool IsDirChangeObservingAvailable(const char *_path) override;
    virtual VFSHostDirObservationTicket DirChangeObserve(const char *_path, function<void()> _handler) override;
    virtual void StopDirChangeObserving(unsigned long _ticket) override;
    
    virtual int CalculateDirectoriesSizes(
                                        const vector<string> &_dirs,
                                        const char *_root_path,
                                        VFSCancelChecker _cancel_checker,
                                        function<void(const char* _dir_sh_name, uint64_t _size)> _completion_handler
                                        ) override;
    
    virtual int ReadSymlink(const char *_path,
                            char *_buffer,
                            size_t _buffer_size,
                            VFSCancelChecker _cancel_checker) override;
    
    virtual int CreateSymlink(const char *_symlink_path,
                              const char *_symlink_value,
                              VFSCancelChecker _cancel_checker) override;
    
    virtual int Unlink(const char *_path, VFSCancelChecker _cancel_checker) override;
    
    virtual int Rename(const char *_old_path, const char *_new_path, VFSCancelChecker _cancel_checker) override;
    
    virtual int SetTimes(const char *_path,
                         int _flags,
                         struct timespec *_birth_time,
                         struct timespec *_mod_time,
                         struct timespec *_chg_time,
                         struct timespec *_acc_time,
                         VFSCancelChecker _cancel_checker
                         ) override;
    
    shared_ptr<const VFSNativeHost> SharedPtr() const {return static_pointer_cast<const VFSNativeHost>(VFSHost::SharedPtr());}
    shared_ptr<VFSNativeHost> SharedPtr() {return static_pointer_cast<VFSNativeHost>(VFSHost::SharedPtr());}
    static const shared_ptr<VFSNativeHost> &SharedHost();
    virtual bool IsNativeFS() const noexcept override;
private:
    
    

};
