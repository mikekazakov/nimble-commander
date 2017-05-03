//
//  VFSNetSFTPHost.h
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFSHost.h>

typedef struct _LIBSSH2_SFTP    LIBSSH2_SFTP;
typedef struct _LIBSSH2_SESSION LIBSSH2_SESSION;
typedef struct _LIBSSH2_USERAUTH_KBDINT_PROMPT LIBSSH2_USERAUTH_KBDINT_PROMPT;
typedef struct _LIBSSH2_USERAUTH_KBDINT_RESPONSE LIBSSH2_USERAUTH_KBDINT_RESPONSE;

class VFSNetSFTPHost final : public VFSHost
{
public:
    // vfs identity
    static  const char *Tag;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    // construction
    VFSNetSFTPHost(const string &_serv_url,
                   const string &_user,
                   const string &_passwd, // when keypath is empty passwd is password for auth, otherwise it's a keyphrase for decrypting private key
                   const string &_keypath, // full path to private key
                   long          _port = 22,
                   const string &_home = "");
    VFSNetSFTPHost(const VFSConfiguration &_config); // should be of type VFSNetSFTPHostConfiguration
    
    const string& HomeDir() const; // no guarantees about trailing slash
    const string& ServerUrl() const noexcept;
    const string& User() const noexcept;
    const string& Keypath() const noexcept;
    long          Port() const noexcept;

    // core VFSHost methods
    virtual bool IsWritable() const override;
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     int _flags,
                     const VFSCancelChecker &_cancel_checker) override;
    
    virtual int StatFS(const char *_path,
                       VFSStatFS &_stat,
                       const VFSCancelChecker &_cancel_checker) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                     shared_ptr<VFSListing> &_target,
                                     int _flags,
                                     const VFSCancelChecker &_cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path,
                                        const function<bool(const VFSDirEnt &_dirent)> &_handler) override;
    
    
    virtual int CreateFile(const char* _path,
                           shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Unlink(const char *_path, const VFSCancelChecker &_cancel_checker) override;
    virtual int Rename(const char *_old_path, const char *_new_path, const VFSCancelChecker &_cancel_checker) override;
    virtual int CreateDirectory(const char* _path, int _mode, const VFSCancelChecker &_cancel_checker) override;
    virtual int RemoveDirectory(const char *_path, const VFSCancelChecker &_cancel_checker) override;
    
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
    
    int VFSErrorForConnection(Connection &_conn) const;
    int GetConnection(unique_ptr<Connection> &_t);
    void ReturnConnection(unique_ptr<Connection> _t);
    
    shared_ptr<const VFSNetSFTPHost> SharedPtr() const {return static_pointer_cast<const VFSNetSFTPHost>(VFSHost::SharedPtr());}
    shared_ptr<VFSNetSFTPHost> SharedPtr() {return static_pointer_cast<VFSNetSFTPHost>(VFSHost::SharedPtr());}
    
private:
    struct AutoConnectionReturn;
    
    static void SpawnSSH2_KbdCallback(const char *name, int name_len, const char *instruction, int instruction_len,
                                      int num_prompts, const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
                                    LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses, void **abstract);
    int DoInit();
    int SpawnSSH2(unique_ptr<Connection> &_t);
    int SpawnSFTP(unique_ptr<Connection> &_t);
    
    in_addr_t InetAddr() const;
    const class VFSNetSFTPHostConfiguration &Config() const;
    
    vector<unique_ptr<Connection>>              m_Connections;
    mutex                                       m_ConnectionsLock;
    VFSConfiguration                            m_Config;
    string                                      m_HomeDir;
    in_addr_t                                   m_HostAddr = 0;
};
