// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/Host.h>
#include <mutex>

typedef struct _LIBSSH2_SFTP    LIBSSH2_SFTP;
typedef struct _LIBSSH2_SESSION LIBSSH2_SESSION;
typedef struct _LIBSSH2_USERAUTH_KBDINT_PROMPT LIBSSH2_USERAUTH_KBDINT_PROMPT;
typedef struct _LIBSSH2_USERAUTH_KBDINT_RESPONSE LIBSSH2_USERAUTH_KBDINT_RESPONSE;

#include "OSType.h"

namespace nc::vfs {

class SFTPHost final : public Host
{
public:
    // vfs identity
    static  const char *UniqueTag;
    virtual VFSConfiguration Configuration() const override;
    static VFSMeta Meta();
    
    // construction
    SFTPHost(const std::string &_serv_url,
             const std::string &_user,
             const std::string &_passwd, // when keypath is empty passwd is password for auth, otherwise it's a keyphrase for decrypting private key
             const std::string &_keypath, // full path to private key
             long          _port = 22,
             const std::string &_home = "");
    SFTPHost(const VFSConfiguration &_config); // should be of type VFSNetSFTPHostConfiguration
    
    const std::string& HomeDir() const; // no guarantees about trailing slash
    const std::string& ServerUrl() const noexcept;
    const std::string& User() const noexcept;
    const std::string& Keypath() const noexcept;
    long          Port() const noexcept;

    // core VFSHost methods
    virtual bool IsWritable() const override;
    
    virtual int Stat(const char *_path,
                     VFSStat &_st,
                     unsigned long _flags,
                     const VFSCancelChecker &_cancel_checker) override;
    
    virtual int StatFS(const char *_path,
                       VFSStatFS &_stat,
                       const VFSCancelChecker &_cancel_checker) override;
    
    virtual int FetchDirectoryListing(const char *_path,
                                     std::shared_ptr<VFSListing> &_target,
                                     unsigned long _flags,
                                     const VFSCancelChecker &_cancel_checker) override;
    
    virtual int IterateDirectoryListing(const char *_path,
                                        const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;
    
    
    virtual int CreateFile(const char* _path,
                           std::shared_ptr<VFSFile> &_target,
                           const VFSCancelChecker &_cancel_checker) override;
    
    virtual int Unlink(const char *_path, const VFSCancelChecker &_cancel_checker) override;
    virtual int Rename(const char *_old_path, const char *_new_path, const VFSCancelChecker &_cancel_checker) override;
    virtual int CreateDirectory(const char* _path, int _mode, const VFSCancelChecker &_cancel_checker) override;
    virtual int RemoveDirectory(const char *_path, const VFSCancelChecker &_cancel_checker) override;
    virtual int ReadSymlink(const char *_symlink_path,
                            char *_buffer,
                            size_t _buffer_size,
                            const VFSCancelChecker &_cancel_checker) override;
    virtual int CreateSymlink(const char *_symlink_path,
                              const char *_symlink_value,
                              const VFSCancelChecker &_cancel_checker) override;
    virtual int SetPermissions(const char *_path,
                      uint16_t _mode,
                      const VFSCancelChecker &_cancel_checker) override;
    virtual int SetOwnership(const char *_path,
                             unsigned _uid,
                             unsigned _gid,
                             const VFSCancelChecker &_cancel_checker) override;
    virtual int SetTimes(const char *_path,
                         std::optional<time_t> _birth_time,
                         std::optional<time_t> _mod_time,
                         std::optional<time_t> _chg_time,
                         std::optional<time_t> _acc_time,
                         const VFSCancelChecker &_cancel_checker) override;
    virtual int FetchUsers(std::vector<VFSUser> &_target,
                           const VFSCancelChecker &_cancel_checker) override;
    virtual int FetchGroups(std::vector<VFSGroup> &_target,
                            const VFSCancelChecker &_cancel_checker) override;
    
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
    int GetConnection(std::unique_ptr<Connection> &_t);
    void ReturnConnection(std::unique_ptr<Connection> _t);
    
    std::shared_ptr<const SFTPHost> SharedPtr() const {return std::static_pointer_cast<const SFTPHost>(Host::SharedPtr());}
    std::shared_ptr<SFTPHost> SharedPtr() {return std::static_pointer_cast<SFTPHost>(Host::SharedPtr());}
    
private:
    struct AutoConnectionReturn;
    
    static void SpawnSSH2_KbdCallback(const char *name, int name_len, const char *instruction, int instruction_len,
                                      int num_prompts, const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
                                    LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses, void **abstract);
    int DoInit();
    int SpawnSSH2(std::unique_ptr<Connection> &_t);
    int SpawnSFTP(std::unique_ptr<Connection> &_t);
    
    in_addr_t InetAddr() const;
    const class SFTPHostConfiguration &Config() const;
    
    std::vector<std::unique_ptr<Connection>>    m_Connections;
    std::mutex                                  m_ConnectionsLock;
    VFSConfiguration                            m_Config;
    std::string                                 m_HomeDir;
    in_addr_t                                   m_HostAddr = 0;
    bool                                        m_ReversedSymlinkParameters = false;
    sftp::OSType                                m_OSType = sftp::OSType::Unknown;
};

}
