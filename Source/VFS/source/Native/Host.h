// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
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
    bool IsCaseSensitiveAtPath(std::string_view _directory) const override;

    int StatFS(std::string_view _path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker = {}) override;

    int Stat(std::string_view _path,
             VFSStat &_st,
             unsigned long _flags,
             const VFSCancelChecker &_cancel_checker = {}) override;

    int FetchDirectoryListing(std::string_view _path,
                              VFSListingPtr &_target,
                              unsigned long _flags,
                              const VFSCancelChecker &_cancel_checker = {}) override;

    int FetchSingleItemListing(std::string_view _path_to_item,
                               VFSListingPtr &_target,
                               unsigned long _flags,
                               const VFSCancelChecker &_cancel_checker = {}) override;

    int IterateDirectoryListing(std::string_view _path,
                                const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    int CreateFile(std::string_view _path,
                   std::shared_ptr<VFSFile> &_target,
                   const VFSCancelChecker &_cancel_checker = nullptr) override;

    int CreateDirectory(std::string_view _path, int _mode, const VFSCancelChecker &_cancel_checker = {}) override;

    int RemoveDirectory(std::string_view _path, const VFSCancelChecker &_cancel_checker = {}) override;

    bool IsDirectoryChangeObservationAvailable(std::string_view _path) override;
    HostDirObservationTicket ObserveDirectoryChanges(std::string_view _path, std::function<void()> _handler) override;

    void StopDirChangeObserving(unsigned long _ticket) override;

    FileObservationToken ObserveFileChanges(std::string_view _path, std::function<void()> _handler) override;

    void StopObservingFileChanges(unsigned long _token) override;

    ssize_t CalculateDirectorySize(std::string_view _path, const VFSCancelChecker &_cancel_checker = {}) override;

    int
    ReadSymlink(std::string_view _path, std::span<char> _buffer, const VFSCancelChecker &_cancel_checker = {}) override;

    int CreateSymlink(std::string_view _symlink_path,
                      std::string_view _symlink_value,
                      const VFSCancelChecker &_cancel_checker = {}) override;

    int Unlink(std::string_view _path, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, nc::Error> Trash(std::string_view _path, const VFSCancelChecker &_cancel_checker = {}) override;

    int Rename(std::string_view _old_path,
               std::string_view _new_path,
               const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error>
    SetPermissions(std::string_view _path, uint16_t _mode, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> SetFlags(std::string_view _path,
                                        uint32_t _flags,
                                        uint64_t _vfs_options,
                                        const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> SetOwnership(std::string_view _path,
                                            unsigned _uid,
                                            unsigned _gid,
                                            const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> SetTimes(std::string_view _path,
                                        std::optional<time_t> _birth_time,
                                        std::optional<time_t> _mod_time,
                                        std::optional<time_t> _chg_time,
                                        std::optional<time_t> _acc_time,
                                        const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<std::vector<VFSUser>, Error> FetchUsers(const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<std::vector<VFSGroup>, Error> FetchGroups(const VFSCancelChecker &_cancel_checker = {}) override;

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
