#pragma once

#include "../../include/VFS/VFSHost.h"

namespace nc::vfs {

namespace webdav {
    class HostConfiguration;
    class ConnectionsPool;
    class Cache;
}

class WebDAVHost final : public VFSHost
{
public:
    static const char *UniqueTag;

    WebDAVHost(const string &_serv_url,
               const string &_user,
               const string &_passwd,
               const string &_path,
               bool _https = false,
               int _port = -1);
    ~WebDAVHost();
    
    
    VFSConfiguration Configuration() const override;
    
    bool IsWritable() const override;
    
    int FetchDirectoryListing(const char *_path,
                              shared_ptr<VFSListing> &_target,
                              int _flags,
                              const VFSCancelChecker &_cancel_checker) override;
    
    int IterateDirectoryListing(const char *_path,
                                const function<bool(const VFSDirEnt &_dirent)> &_handler) override;
    int Stat(const char *_path,
             VFSStat &_st,
             int _flags,
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
    
    
    const webdav::HostConfiguration &Config() const noexcept;
    class webdav::ConnectionsPool &ConnectionsPool();
    class webdav::Cache &Cache();
    
private:
    int RefreshListingAtPath( const string &_path, const VFSCancelChecker &_cancel_checker );


    struct State;
    unique_ptr<State> I;
    VFSConfiguration m_Configuration;
};

}
