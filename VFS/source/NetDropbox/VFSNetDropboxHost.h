#pragma once

#include <VFS/VFSHost.h>

class VFSNetDropboxHost : public VFSHost
{
public:
    static const char *Tag;

    VFSNetDropboxHost( const string &_access_token );

    virtual int StatFS(const char *_path,
                       VFSStatFS &_stat,
                       const VFSCancelChecker &_cancel_checker) override;

    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     const VFSCancelChecker &_cancel_checker) override;


private:
    const string m_Token;
    
};
