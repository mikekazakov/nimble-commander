#pragma once

#include <VFS/VFSHost.h>
#include <VFS/VFSFile.h>

/**
 * This every API call may take seconds to complete, VFSNetDropboxHost assumes primarily background
 * usage. When called from the main thread, this VFS will bug caller's console with warning. 
 */
class VFSNetDropboxHost final : public VFSHost
{
public:
    static const char *Tag;

    VFSNetDropboxHost( const string &_access_token );
    ~VFSNetDropboxHost();

    bool ShouldProduceThumbnails() const override;
    
    virtual bool IsWritable() const override;
    
    virtual int StatFS(const char *_path,
                       VFSStatFS &_stat,
                       const VFSCancelChecker &_cancel_checker) override;

    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
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
                                      int _flags,
                                      const VFSCancelChecker &_cancel_checker) override;

    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;
    
    virtual int CreateDirectory(const char* _path,
                                int _mode,
                                const VFSCancelChecker &_cancel_checker ) override;

    shared_ptr<const VFSNetDropboxHost> SharedPtr() const {return static_pointer_cast<const VFSNetDropboxHost>(VFSHost::SharedPtr());}
    shared_ptr<VFSNetDropboxHost> SharedPtr() {return static_pointer_cast<VFSNetDropboxHost>(VFSHost::SharedPtr());}

    const string &Token() const;

#ifdef __OBJC__
    void FillAuth( NSMutableURLRequest *_request );
    NSURLSession *GenericSession();
#endif

private:
    void InitialAccountLookup(); // will throw on invalid account / connectivity issues

    struct State;
    unique_ptr<State> I;
};
