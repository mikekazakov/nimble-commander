//
//  VFSNetSFTPHost.h
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "VFSHost.h"

typedef struct _LIBSSH2_SFTP    LIBSSH2_SFTP;
typedef struct _LIBSSH2_SESSION LIBSSH2_SESSION;

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
    // vfs identity
    static  const char *Tag;
    virtual const char *FSTag() const override;
    
    
    // construction
    VFSNetSFTPHost(const char *_serv_url);
    int Open(const VFSNetSFTPOptions &_options = VFSNetSFTPOptions());
    
    const string& HomeDir() const;

    // core VFSHost methods
    virtual bool IsWriteable() const override;
    virtual bool IsWriteableAtPath(const char *_dir) const override;
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     bool (^_cancel_checker)());
    
    virtual int StatFS(const char *_path,
                       VFSStatFS &_stat,
                       bool (^_cancel_checker)()) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                      shared_ptr<VFSListing> *_target,
                                      int _flags,
                                      bool (^_cancel_checker)()) override;
    
    virtual int IterateDirectoryListing(const char *_path,
                                        bool (^_handler)(const VFSDirEnt &_dirent)) override;
    
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           bool (^_cancel_checker)()) override;
    
    virtual string VerboseJunctionPath() const override;
    virtual shared_ptr<VFSHostOptions> Options() const override;
    virtual bool ShouldProduceThumbnails() const override;
    
    // internal stuff
    struct Connection
    {
        ~Connection();
        bool Alive() const;
        LIBSSH2_SFTP       *sftp   = nullptr;
        LIBSSH2_SESSION    *ssh    = nullptr;
        int                 socket = -1;
    };
    
    
    int GetConnection(unique_ptr<Connection> &_t);
    void ReturnConnection(unique_ptr<Connection> _t);
    
    VFS_DECLARE_SHARED_PTR(VFSNetSFTPHost);
private:
    int SpawnSSH2(unique_ptr<Connection> &_t);
    int SpawnSFTP(unique_ptr<Connection> &_t);
    
    in_addr_t InetAddr() const;
    
    list<unique_ptr<Connection>>                m_Connections;
    mutex                                       m_ConnectionsLock;
    shared_ptr<VFSNetSFTPOptions>               m_Options;
    string                                      m_HomeDir;
    in_addr_t                                   m_HostAddr = 0;
};
