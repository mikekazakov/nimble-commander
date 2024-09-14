// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/Host.h>

namespace nc::utility {
class NativeFSManager;
class FSEventsFileUpdate;
} // namespace nc::utility

namespace nc::vfs {

class NativeHost : public Host
{
public:
    NativeHost(nc::utility::NativeFSManager &_native_fs_man, nc::utility::FSEventsFileUpdate &_fsevents_file_update);

    static const char *UniqueTag;
    VFSConfiguration Configuration() const override;
    static VFSMeta Meta();

    bool IsWritable() const override;
    bool IsCaseSensitiveAtPath(const char *_dir) const override;

    int StatFS(const char *_path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker = {}) override;

    int Stat(const char *_path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;

    int FetchDirectoryListing(const char *_path,
                              VFSListingPtr &_target,
                              unsigned long _flags,
                              const VFSCancelChecker &_cancel_checker = {}) override;

    int FetchSingleItemListing(const char *_path_to_item,
                               VFSListingPtr &_target,
                               unsigned long _flags,
                               const VFSCancelChecker &_cancel_checker = {}) override;

    int IterateDirectoryListing(const char *_path,
                                const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    int
    CreateFile(const char *_path, std::shared_ptr<VFSFile> &_target, const VFSCancelChecker &_cancel_checker) override;

    int CreateDirectory(const char *_path, int _mode, const VFSCancelChecker &_cancel_checker) override;

    int RemoveDirectory(const char *_path, const VFSCancelChecker &_cancel_checker) override;

    bool IsDirChangeObservingAvailable(std::string_view _path) override;
    HostDirObservationTicket ObserveDirectoryChanges(std::string_view _path, std::function<void()> _handler) override;

    void StopDirChangeObserving(unsigned long _ticket) override;

    FileObservationToken ObserveFileChanges(std::string_view _path, std::function<void()> _handler) override;

    void StopObservingFileChanges(unsigned long _token) override;

    ssize_t CalculateDirectorySize(const char *_path, const VFSCancelChecker &_cancel_checker) override;

    int ReadSymlink(const char *_path,
                    char *_buffer,
                    size_t _buffer_size,
                    const VFSCancelChecker &_cancel_checker) override;

    int CreateSymlink(const char *_symlink_path,
                      const char *_symlink_value,
                      const VFSCancelChecker &_cancel_checker) override;

    int Unlink(const char *_path, const VFSCancelChecker &_cancel_checker) override;

    int Trash(const char *_path, const VFSCancelChecker &_cancel_checker) override;

    int Rename(const char *_old_path, const char *_new_path, const VFSCancelChecker &_cancel_checker) override;

    int SetPermissions(const char *_path, uint16_t _mode, const VFSCancelChecker &_cancel_checker) override;

    int SetFlags(const char *_path,
                 uint32_t _flags,
                 uint64_t _vfs_options,
                 const VFSCancelChecker &_cancel_checker) override;

    int SetOwnership(const char *_path, unsigned _uid, unsigned _gid, const VFSCancelChecker &_cancel_checker) override;

    int SetTimes(const char *_path,
                 std::optional<time_t> _birth_time,
                 std::optional<time_t> _mod_time,
                 std::optional<time_t> _chg_time,
                 std::optional<time_t> _acc_time,
                 const VFSCancelChecker &_cancel_checker) override;

    int FetchUsers(std::vector<VFSUser> &_target, const VFSCancelChecker &_cancel_checker) override;

    int FetchGroups(std::vector<VFSGroup> &_target, const VFSCancelChecker &_cancel_checker) override;
    bool ShouldProduceThumbnails() const override;

    std::shared_ptr<const NativeHost> SharedPtr() const
    {
        return std::static_pointer_cast<const NativeHost>(Host::SharedPtr());
    }
    std::shared_ptr<NativeHost> SharedPtr() { return std::static_pointer_cast<NativeHost>(Host::SharedPtr()); }

    bool IsNativeFS() const noexcept override;

    nc::utility::NativeFSManager &NativeFSManager() const noexcept;

private:
    nc::utility::NativeFSManager &m_NativeFSManager;
    [[maybe_unused]] nc::utility::FSEventsFileUpdate &m_FSEventsFileUpdate;
};

} // namespace nc::vfs

using VFSNativeHost = nc::vfs::NativeHost;
