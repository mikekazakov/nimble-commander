// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <VFS/Host.h>
#include "InternalsForward.h"
#include <filesystem>
#include <string_view>
#include <map>
#include <mutex>

// RTFM: http://www.ietf.org/rfc/rfc959.txt

namespace nc::vfs {

class FTPHost final : public Host
{
public:
    FTPHost(const std::string &_serv_url,
            const std::string &_user,
            const std::string &_passwd,
            const std::string &_start_dir,
            long _port = 21,
            bool _active = false);
    FTPHost(const VFSConfiguration &_config); // should be of type VFSNetFTPHostConfiguration
    ~FTPHost();

    static const char *UniqueTag;
    static VFSMeta Meta();
    VFSConfiguration Configuration() const override;

    const std::string &ServerUrl() const noexcept;
    const std::string &User() const noexcept;
    long Port() const noexcept;
    bool Active() const noexcept;

    // core VFSHost methods
    std::expected<VFSListingPtr, Error> FetchDirectoryListing(std::string_view _path,
                                                              unsigned long _flags,
                                                              const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error>
    IterateDirectoryListing(std::string_view _path,
                            const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    std::expected<VFSStat, Error>
    Stat(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;

    std::expected<VFSStatFS, Error> StatFS(std::string_view _path, const VFSCancelChecker &_cancel_checker) override;

    std::expected<std::shared_ptr<VFSFile>, Error> CreateFile(std::string_view _path,
                                                              const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error>
    CreateDirectory(std::string_view _path, int _mode, const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error> Unlink(std::string_view _path, const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error> RemoveDirectory(std::string_view _path,
                                               const VFSCancelChecker &_cancel_checker) override;

    std::expected<void, Error>
    Rename(std::string_view _old_path, std::string_view _new_path, const VFSCancelChecker &_cancel_checker) override;

    bool IsWritable() const override;

    bool IsDirectoryChangeObservationAvailable(std::string_view _path) override;

    HostDirObservationTicket ObserveDirectoryChanges(std::string_view _path, std::function<void()> _handler) override;

    void StopDirChangeObserving(unsigned long _ticket) override;

    // internal stuff below:
    std::string BuildFullURLString(std::string_view _path) const;

    void MakeDirectoryStructureDirty(const char *_path);

    std::unique_ptr<ftp::CURLInstance> InstanceForIOAtDir(const std::filesystem::path &_dir);
    void CommitIOInstanceAtDir(const std::filesystem::path &_dir, std::unique_ptr<ftp::CURLInstance> _i);

    ftp::Cache &Cache() const { return *m_Cache.get(); };

    std::shared_ptr<const FTPHost> SharedPtr() const
    {
        return std::static_pointer_cast<const FTPHost>(Host::SharedPtr());
    }
    std::shared_ptr<FTPHost> SharedPtr() { return std::static_pointer_cast<FTPHost>(Host::SharedPtr()); }

private:
    int DoInit();
    int DownloadAndCacheListing(ftp::CURLInstance *_inst,
                                const char *_path,
                                std::shared_ptr<ftp::Directory> *_cached_dir,
                                const VFSCancelChecker &_cancel_checker);

    int GetListingForFetching(ftp::CURLInstance *_inst,
                              std::string_view _path,
                              std::shared_ptr<ftp::Directory> &_cached_dir,
                              const VFSCancelChecker &_cancel_checker);

    std::unique_ptr<ftp::CURLInstance> SpawnCURL();

    int DownloadListing(ftp::CURLInstance *_inst,
                        const char *_path,
                        std::string &_buffer,
                        const VFSCancelChecker &_cancel_checker) const;

    void InformDirectoryChanged(const std::string &_dir_wth_sl);

    void BasicOptsSetup(ftp::CURLInstance *_inst);
    const class VFSNetFTPHostConfiguration &Config() const noexcept;

    std::unique_ptr<ftp::Cache> m_Cache;
    std::unique_ptr<ftp::CURLInstance> m_ListingInstance;

    std::map<std::filesystem::path, std::unique_ptr<ftp::CURLInstance>> m_IOIntances;
    std::mutex m_IOIntancesLock;

    struct UpdateHandler {
        unsigned long ticket;
        std::function<void()> handler;
        std::string path; // path with trailing slash
    };

    std::vector<UpdateHandler> m_UpdateHandlers;
    std::mutex m_UpdateHandlersLock;
    unsigned long m_LastUpdateTicket = 1;
    VFSConfiguration m_Configuration;
};

} // namespace nc::vfs
