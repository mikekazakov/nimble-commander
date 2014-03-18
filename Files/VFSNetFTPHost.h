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
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     bool (^_cancel_checker)()) override;
    
    
    int DownloadAndCacheListing(VFSNetFTP::CURLInstance *_inst,
                                const char *_path,
                                shared_ptr<VFSNetFTP::Directory> *_cached_dir);
    
    VFS_DECLARE_SHARED_PTR(VFSNetFTPHost);
private:
    unique_ptr<VFSNetFTP::CURLInstance> SpawnCURL();
    void BuildFullURL(const char *_path, char *_buffer) const;    
    int DownloadListing(VFSNetFTP::CURLInstance *_inst, const char *_path, string &_buffer);
    
    unique_ptr<VFSNetFTP::Cache>        m_Cache;
    unique_ptr<VFSNetFTP::CURLInstance> m_ListingInstance;
};
