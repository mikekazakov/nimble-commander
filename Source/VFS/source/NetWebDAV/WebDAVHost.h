// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../../include/VFS/Host.h"

namespace nc::vfs {

namespace webdav {
class HostConfiguration;
class ConnectionsPool;
class Cache;
} // namespace webdav

class WebDAVHost final : public Host
{
public:
    static const char *UniqueTag;

    WebDAVHost(const std::string &_serv_url,
               const std::string &_user,
               const std::string &_passwd,
               const std::string &_path,
               bool _https = false,
               int _port = -1);
    WebDAVHost(const VFSConfiguration &_config);
    ~WebDAVHost();

    VFSConfiguration Configuration() const override;

    static VFSMeta Meta();

    bool IsWritable() const override;

    int FetchDirectoryListing(std::string_view _path,
                              VFSListingPtr &_target,
                              unsigned long _flags,
                              const VFSCancelChecker &_cancel_checker) override;

    int IterateDirectoryListing(std::string_view _path,
                                const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;
    int
    Stat(std::string_view _path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;

    int StatFS(std::string_view _path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker) override;

    int CreateDirectory(std::string_view _path, int _mode, const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error> RemoveDirectory(std::string_view _path,
                                               const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error> Unlink(std::string_view _path, const VFSCancelChecker &_cancel_checker) override;

    int CreateFile(std::string_view _path,
                   std::shared_ptr<VFSFile> &_target,
                   const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error>
    Rename(std::string_view _old_path, std::string_view _new_path, const VFSCancelChecker &_cancel_checker) override;

    bool IsDirectoryChangeObservationAvailable(std::string_view _path) override;

    HostDirObservationTicket ObserveDirectoryChanges(std::string_view _path, std::function<void()> _handler) override;

    const std::string &Host() const noexcept;
    const std::string &Path() const noexcept;
    const std::string Username() const noexcept;
    int Port() const noexcept;

    const webdav::HostConfiguration &Config() const noexcept;
    class webdav::ConnectionsPool &ConnectionsPool();
    class webdav::Cache &Cache();

private:
    void Init();
    void StopDirChangeObserving(unsigned long _ticket) override;
    int RefreshListingAtPath(const std::string &_path, const VFSCancelChecker &_cancel_checker);

    struct State;
    std::unique_ptr<State> I;
    VFSConfiguration m_Configuration;
};

} // namespace nc::vfs
