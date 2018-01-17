// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/Host.h>

namespace nc::vfs {

class NativeHost final : public Host
{
public:
    NativeHost();
    
    static const char *UniqueTag;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    virtual bool IsWritable() const override;
    virtual bool IsCaseSensitiveAtPath(const char *_dir) const override;
    
    virtual int StatFS(const char *_path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> &_target,
                                      unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker) override;
    
    virtual int FetchSingleItemListing(const char *_path_to_item,
                                       shared_ptr<VFSListing> &_target,
                                       unsigned long _flags,
                                       const VFSCancelChecker &_cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path, const function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;
    
    virtual int CreateDirectory(const char* _path,
                                int _mode,
                                const VFSCancelChecker &_cancel_checker) override;
    
    virtual int RemoveDirectory(const char *_path, const VFSCancelChecker &_cancel_checker) override;
    
    virtual bool IsDirChangeObservingAvailable(const char *_path) override;
    virtual HostDirObservationTicket DirChangeObserve(const char *_path, function<void()> _handler) override;
    virtual void StopDirChangeObserving(unsigned long _ticket) override;
    
    virtual ssize_t CalculateDirectorySize(const char *_path,
                                           const VFSCancelChecker &_cancel_checker) override;
    
    virtual int ReadSymlink(const char *_path,
                            char *_buffer,
                            size_t _buffer_size,
                            const VFSCancelChecker &_cancel_checker) override;
    
    virtual int CreateSymlink(const char *_symlink_path,
                              const char *_symlink_value,
                              const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Unlink(const char *_path, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Trash(const char *_path, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Rename(const char *_old_path, const char *_new_path, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int SetPermissions(const char *_path, uint16_t _mode, const VFSCancelChecker &_cancel_checker) override;
    virtual int SetFlags(const char *_path, uint32_t _flags, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int SetOwnership(const char *_path, unsigned _uid, unsigned _gid, const VFSCancelChecker &_cancel_checker) override;
    
    virtual int SetTimes(const char *_path,
                         optional<time_t> _birth_time,
                         optional<time_t> _mod_time,
                         optional<time_t> _chg_time,
                         optional<time_t> _acc_time,
                         const VFSCancelChecker &_cancel_checker) override;

    virtual int FetchUsers(vector<VFSUser> &_target,
                           const VFSCancelChecker &_cancel_checker) override;

    virtual int FetchGroups(vector<VFSGroup> &_target,
                            const VFSCancelChecker &_cancel_checker) override;
    virtual bool ShouldProduceThumbnails() const override;
    
    shared_ptr<const NativeHost> SharedPtr() const {return static_pointer_cast<const NativeHost>(Host::SharedPtr());}
    shared_ptr<NativeHost> SharedPtr() {return static_pointer_cast<NativeHost>(Host::SharedPtr());}
    static const shared_ptr<NativeHost> &SharedHost() noexcept;
    virtual bool IsNativeFS() const noexcept override;
private:
    
};

}

using VFSNativeHost = nc::vfs::NativeHost;
