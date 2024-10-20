// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/Host.h>
#include <VFS/VFSFile.h>

#ifdef __OBJC__
#include "NSURLShims.h"
#endif

namespace nc::vfs {

namespace dropbox {
class URLSessionCreator;
}

/**
 * This every API call may take seconds to complete, VFSNetDropboxHost assumes primarily background
 * usage. When called from the main thread, this VFS will bug caller's console with warning.
 */
class DropboxHost final : public Host
{
public:
    static const char *UniqueTag;

    struct Params {
        std::string account;
        std::string access_token;
        std::string client_id;
        std::string client_secret;
        // An object used to create NSURLSession objects.
        // This shim is required for unit-testability.
        // If it's nullptr, then dropbox::URLSessionFactory::DefaultFactory() will be used.
        dropbox::URLSessionCreator *session_creator = nullptr;
    };
    DropboxHost(const Params &_params);
    DropboxHost(const VFSConfiguration &_config);
    ~DropboxHost();

    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();

    virtual bool IsWritable() const override;
    virtual bool IsCaseSensitiveAtPath(std::string_view _dir) const override;
    virtual int StatFS(std::string_view _path, VFSStatFS &_stat, const VFSCancelChecker &_cancel_checker) override;

    virtual int
    Stat(std::string_view _path, VFSStat &_st, unsigned long _flags, const VFSCancelChecker &_cancel_checker) override;

    virtual int Unlink(std::string_view _path, const VFSCancelChecker &_cancel_checker) override;

    virtual int RemoveDirectory(std::string_view _path, const VFSCancelChecker &_cancel_checker) override;

    virtual int IterateDirectoryListing(std::string_view _path,
                                        const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    virtual int FetchDirectoryListing(std::string_view _path,
                                      VFSListingPtr &_target,
                                      unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker) override;

    virtual int CreateFile(std::string_view _path,
                           std::shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;

    virtual int CreateDirectory(std::string_view _path, int _mode, const VFSCancelChecker &_cancel_checker) override;

    virtual int
    Rename(std::string_view _old_path, std::string_view _new_path, const VFSCancelChecker &_cancel_checker) override;

    std::shared_ptr<const DropboxHost> SharedPtr() const noexcept;
    std::shared_ptr<DropboxHost> SharedPtr() noexcept;

    const std::string &Account() const;
    const std::string &Token() const;

#ifdef __OBJC__
    void FillAuth(NSMutableURLRequest *_request) const;
    NSURLSession *GenericSession() const;
    static NSURLSessionConfiguration *GenericConfiguration();
#endif

    static std::pair<int, std::string> CheckTokenAndRetrieveAccountEmail(const std::string &_token);

private:
    void Init();
    void Construct(const std::string &_account, const std::string &_access_token);
    void SetAccessToken(const std::string &_access_token);
    void InitialAccountLookup(); // will throw on invalid account / connectivity issues

    std::pair<int, std::string> RetreiveAccessTokenFromRefreshToken(const std::string &_refresh_token);

#ifdef __OBJC__
    // Sets HTTPMethod to POST
    // Handles Authentications, can update an access token if the current one is expired and
    // a refresh token is available.
    std::pair<int, NSData *> SendSynchronousPostRequest(NSMutableURLRequest *_request,
                                                        const VFSCancelChecker &_cancel_checker = {});
#endif

    const class VFSNetDropboxHostConfiguration &Config() const;

    struct State;
    std::unique_ptr<State> I;
    VFSConfiguration m_Config;
};

} // namespace nc::vfs
