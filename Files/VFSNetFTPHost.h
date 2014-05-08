//
//  VFSNetFTPHost.h
//  Files
//
//  Created by Michael G. Kazakov on 17.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import "VFSHost.h"
#import "VFSNetFTPInternalsForward.h"

// RTFM: http://www.ietf.org/rfc/rfc959.txt

struct VFSNetFTPOptions
{
    
    
};

class VFSNetFTPHost : public VFSHost
{
public:
    VFSNetFTPHost(const char *_serv_url); // like 'localhost', or '192.168.2.5' or 'ftp.microsoft.com'
    ~VFSNetFTPHost();

    static  const char *Tag;
    virtual const char *FSTag() const override;
    
    /**
     * return VFS error code, 0 if opened ok.
     * upon opening will read starting directory listing
     */
    int Open(const char *_starting_dir,
             const VFSNetFTPOptions *_options
             );
    
    // core VFSHost methods
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,
                                      bool (^_cancel_checker)()) override;
    
    virtual int IterateDirectoryListing(const char *_path, bool (^_handler)(const VFSDirEnt &_dirent)) override;
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     bool (^_cancel_checker)()) override;

    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           bool (^_cancel_checker)()) override;
    
    virtual int CreateDirectory(const char* _path,
                                bool (^_cancel_checker)()
                                ) override;
    
    virtual int Unlink(const char *_path, bool (^_cancel_checker)());
    virtual int RemoveDirectory(const char *_path, bool (^_cancel_checker)()) override;
    
    
    virtual bool ShouldProduceThumbnails() override;
    virtual bool IsWriteable() const override;
    virtual bool IsWriteableAtPath(const char *_dir) const override;
    
    virtual unsigned long DirChangeObserve(const char *_path, void (^_handler)()) override;
    virtual void StopDirChangeObserving(unsigned long _ticket) override;    
    
    // internal stuff below:
    void BuildFullURL(const char *_path, char *_buffer) const;
    string BuildFullURLString(const char *_path) const;

    void MakeDirectoryStructureDirty(const char *_path);
    
    unique_ptr<VFSNetFTP::CURLInstance> InstanceForIO();
    
    unique_ptr<VFSNetFTP::CURLInstance> InstanceForIOAtDir(const char *_dir);
    void CommitIOInstanceAtDir(const char *_dir, unique_ptr<VFSNetFTP::CURLInstance> _i);
    
    
    inline VFSNetFTP::Cache &Cache() const { return *m_Cache.get(); };
    
    VFS_DECLARE_SHARED_PTR(VFSNetFTPHost);
private:
    int DownloadAndCacheListing(VFSNetFTP::CURLInstance *_inst,
                                const char *_path,
                                shared_ptr<VFSNetFTP::Directory> *_cached_dir,
                                bool (^_cancel_checker)());
    
    int GetListingForFetching(VFSNetFTP::CURLInstance *_inst,
                         const char *_path,
                         shared_ptr<VFSNetFTP::Directory> *_cached_dir,
                         bool (^_cancel_checker)());
    
    unique_ptr<VFSNetFTP::CURLInstance> SpawnCURL();
    
    int DownloadListing(VFSNetFTP::CURLInstance *_inst,
                        const char *_path,
                        string &_buffer,
                        bool (^_cancel_checker)());
    
    void InformDirectoryChanged(const string &_dir_wth_sl);
    
    unique_ptr<VFSNetFTP::Cache>        m_Cache;
    unique_ptr<VFSNetFTP::CURLInstance> m_ListingInstance;
    
    map<path, unique_ptr<VFSNetFTP::CURLInstance>> m_IOIntances;
    
    struct UpdateHandler
    {
        unsigned long ticket;
        void        (^handler)();
        string        path; // path with trailing slash
    };

    vector<UpdateHandler> m_UpdateHandlers;
    mutex                 m_UpdateHandlersLock;
    unsigned long         m_LastUpdateTicket = 1;
};
