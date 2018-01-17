// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/Host.h>
#include <VFS/VFSFile.h>

namespace nc::vfs {

/**
 * This every API call may take seconds to complete, VFSNetDropboxHost assumes primarily background
 * usage. When called from the main thread, this VFS will bug caller's console with warning. 
 */
class DropboxHost final : public Host
{
public:
    static const char *UniqueTag;

    DropboxHost( const string &_account, const string &_access_token );
    DropboxHost( const VFSConfiguration &_config );
    ~DropboxHost();

    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    virtual bool IsWritable() const override;
    virtual bool IsCaseSensitiveAtPath(const char *_dir) const override;    
    virtual int StatFS(const char *_path,
                       VFSStatFS &_stat,
                       const VFSCancelChecker &_cancel_checker) override;

    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     unsigned long _flags,
                     const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Unlink(const char *_path,
                       const VFSCancelChecker &_cancel_checker ) override;

    virtual int RemoveDirectory(const char *_path,
                                const VFSCancelChecker &_cancel_checker ) override;

    virtual int IterateDirectoryListing(const char *_path,
                                        const function<bool(const VFSDirEnt &_dirent)> &_handler)
                                        override;

    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> &_target,
                                      unsigned long _flags,
                                      const VFSCancelChecker &_cancel_checker) override;

    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;
    
    virtual int CreateDirectory(const char* _path,
                                int _mode,
                                const VFSCancelChecker &_cancel_checker ) override;
    
    virtual int Rename(const char *_old_path,
                       const char *_new_path,
                       const VFSCancelChecker &_cancel_checker ) override;

    shared_ptr<const DropboxHost> SharedPtr() const {return static_pointer_cast<const DropboxHost>(Host::SharedPtr());}
    shared_ptr<DropboxHost> SharedPtr() {return static_pointer_cast<DropboxHost>(Host::SharedPtr());}

    const string &Account() const;
    const string &Token() const;

#ifdef __OBJC__
    void FillAuth( NSMutableURLRequest *_request ) const;
    NSURLSession *GenericSession() const;
    NSURLSessionConfiguration *GenericConfiguration() const;
#endif

    static pair<int, string> CheckTokenAndRetrieveAccountEmail( const string &_token );
private:
    void Init();
    void Construct(const string &_account, const string &_access_token);
    void InitialAccountLookup(); // will throw on invalid account / connectivity issues
    const class VFSNetDropboxHostConfiguration &Config() const;

    struct State;
    unique_ptr<State> I;
    VFSConfiguration m_Config;    
};

}
