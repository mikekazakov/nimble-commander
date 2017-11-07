// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../../include/VFS/Host.h"

namespace nc::vfs {

namespace webdav {
    class HostConfiguration;
    class ConnectionsPool;
    class Cache;
}

class WebDAVHost final : public Host
{
public:
    static const char *UniqueTag;

    WebDAVHost(const string &_serv_url,
               const string &_user,
               const string &_passwd,
               const string &_path,
               bool _https = false,
               int _port = -1);
    WebDAVHost( const VFSConfiguration &_config );               
    ~WebDAVHost();
    
    VFSConfiguration Configuration() const override;
    
    static VFSMeta Meta();    
    
    bool IsWritable() const override;
    
    int FetchDirectoryListing(const char *_path,
                              shared_ptr<VFSListing> &_target,
                              unsigned long _flags,
                              const VFSCancelChecker &_cancel_checker) override;
    
    int IterateDirectoryListing(const char *_path,
                                const function<bool(const VFSDirEnt &_dirent)> &_handler) override;
    int Stat(const char *_path,
             VFSStat &_st,
             unsigned long _flags,
             const VFSCancelChecker &_cancel_checker) override;
    
    int StatFS(const char *_path,
               VFSStatFS &_stat,
               const VFSCancelChecker &_cancel_checker) override;
    
    int CreateDirectory(const char* _path,
                        int _mode,
                        const VFSCancelChecker &_cancel_checker) override;
    
    int RemoveDirectory(const char *_path, const VFSCancelChecker &_cancel_checker) override;    

    int Unlink(const char *_path,
               const VFSCancelChecker &_cancel_checker ) override;
    
    int CreateFile(const char* _path,
                   shared_ptr<VFSFile> &_target,
                   const VFSCancelChecker &_cancel_checker) override;
    
    int Rename(const char *_old_path,
               const char *_new_path,
               const VFSCancelChecker &_cancel_checker ) override;
    
    bool IsDirChangeObservingAvailable(const char *_path) override;
    
    HostDirObservationTicket DirChangeObserve(const char *_path,
                                              function<void()> _handler) override;
    
    const string &Host() const noexcept;
    const string &Path() const noexcept;
    const string Username() const noexcept;
    const int Port() const noexcept;
    
    const webdav::HostConfiguration &Config() const noexcept;
    class webdav::ConnectionsPool &ConnectionsPool();
    class webdav::Cache &Cache();
    
private:
    void Init();
    void StopDirChangeObserving(unsigned long _ticket) override;
    int RefreshListingAtPath( const string &_path, const VFSCancelChecker &_cancel_checker );


    struct State;
    unique_ptr<State> I;
    VFSConfiguration m_Configuration;
};

}
