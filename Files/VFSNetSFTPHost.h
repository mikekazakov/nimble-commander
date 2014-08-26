//
//  VFSNetSFTPHost.h
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSHost.h"

namespace VFSNetSFTP
{
    struct Connection;
}

struct VFSNetSFTPOptions : VFSHostOptions
{
    string user;
    string passwd;
    long   port = -1;
    
    bool Equal(const VFSHostOptions &_r) const override;
};

class VFSNetSFTPHost : public VFSHost
{
public:
    VFSNetSFTPHost(const char *_serv_url);
    int Open(const char *_starting_dir,
             const VFSNetSFTPOptions &_options = VFSNetSFTPOptions());
    
    static  const char *Tag;
    virtual const char *FSTag() const override;

    // core VFSHost methods
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     bool (^_cancel_checker)());
    
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,
                                      bool (^_cancel_checker)()) override;
    
    
    int SpawnConnection(unique_ptr<VFSNetSFTP::Connection> &_t);
    
private:
//    in_addr_t hostaddr = inet_addr
    unsigned InetAddr() const; // return IP of a remote host
    
    shared_ptr<VFSNetSFTPOptions>    m_Options;
};
