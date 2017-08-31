#pragma once

#include "../../include/VFS/VFSHost.h"

namespace nc::vfs {

namespace webdav {
    class HostConfiguration;
}

class WebDAVHost : public VFSHost
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
    
    int FetchDirectoryListing(const char *_path,
                              shared_ptr<VFSListing> &_target,
                              int _flags,
                              const VFSCancelChecker &_cancel_checker) override;
    int Stat(const char *_path,
             VFSStat &_st,
             int _flags,
             const VFSCancelChecker &_cancel_checker) override;
    
    
private:
    const webdav::HostConfiguration &Config() const noexcept;
    int RefreshListingAtPath( const string &_path, const VFSCancelChecker &_cancel_checker );


    struct State;
    unique_ptr<State> I;
    VFSConfiguration m_Configuration;
};

}
