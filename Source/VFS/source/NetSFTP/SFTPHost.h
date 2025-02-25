// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/Host.h>
#include <mutex>

typedef struct _LIBSSH2_SFTP LIBSSH2_SFTP;
typedef struct _LIBSSH2_SESSION LIBSSH2_SESSION;
typedef struct _LIBSSH2_USERAUTH_KBDINT_PROMPT LIBSSH2_USERAUTH_KBDINT_PROMPT;
typedef struct _LIBSSH2_USERAUTH_KBDINT_RESPONSE LIBSSH2_USERAUTH_KBDINT_RESPONSE;

#include "OSType.h"

namespace nc::vfs {

class SFTPHost final : public Host
{
public:
    // vfs identity
    static const char *UniqueTag;

    VFSConfiguration Configuration() const override;

    static VFSMeta Meta();

    // construction
    SFTPHost(const std::string &_serv_url,
             const std::string &_user,
             const std::string &_passwd,  // when keypath is empty passwd is password for auth, otherwise it's a
                                          // keyphrase for decrypting private key
             const std::string &_keypath, // full path to private key
             long _port = 22,
             const std::string &_home = "");

    SFTPHost(const VFSConfiguration &_config); // should be of type VFSNetSFTPHostConfiguration

    const std::string &HomeDir() const; // no guarantees about trailing slash

    const std::string &ServerUrl() const noexcept;

    const std::string &User() const noexcept;

    const std::string &Keypath() const noexcept;

    long Port() const noexcept;

    // core VFSHost methods
    bool IsWritable() const override;

    std::expected<VFSStat, Error>
    Stat(std::string_view _path, unsigned long _flags, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<VFSStatFS, Error> StatFS(std::string_view _path,
                                           const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<VFSListingPtr, Error> FetchDirectoryListing(std::string_view _path,
                                                              unsigned long _flags,
                                                              const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error>
    IterateDirectoryListing(std::string_view _path,
                            const std::function<bool(const VFSDirEnt &_dirent)> &_handler) override;

    std::expected<std::shared_ptr<VFSFile>, Error> CreateFile(std::string_view _path,
                                                              const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> Unlink(std::string_view _path, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> Rename(std::string_view _old_path,
                                      std::string_view _new_path,
                                      const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error>
    CreateDirectory(std::string_view _path, int _mode, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> RemoveDirectory(std::string_view _path,
                                               const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<std::string, Error> ReadSymlink(std::string_view _symlink_path,
                                                  const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> CreateSymlink(std::string_view _symlink_path,
                                             std::string_view _symlink_value,
                                             const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error>
    SetPermissions(std::string_view _path, uint16_t _mode, const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> SetOwnership(std::string_view _path,
                                            unsigned _uid,
                                            unsigned _gid,
                                            const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<void, Error> SetTimes(std::string_view _path,
                                        std::optional<time_t> _birth_time,
                                        std::optional<time_t> _mod_time,
                                        std::optional<time_t> _chg_time,
                                        std::optional<time_t> _acc_time,
                                        const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<std::vector<VFSUser>, Error> FetchUsers(const VFSCancelChecker &_cancel_checker = {}) override;

    std::expected<std::vector<VFSGroup>, Error> FetchGroups(const VFSCancelChecker &_cancel_checker = {}) override;

    // internal stuff
    struct Connection {
        ~Connection();
        bool Alive() const;
        LIBSSH2_SFTP *sftp = nullptr;
        LIBSSH2_SESSION *ssh = nullptr;
        int socket = -1;
    };

    static int VFSErrorForConnection(Connection &_conn);
    static std::optional<Error> ErrorForConnection(Connection &_conn);

    int GetConnection(std::unique_ptr<Connection> &_t);

    void ReturnConnection(std::unique_ptr<Connection> _t);

    std::shared_ptr<const SFTPHost> SharedPtr() const
    {
        return std::static_pointer_cast<const SFTPHost>(Host::SharedPtr());
    }

    std::shared_ptr<SFTPHost> SharedPtr() { return std::static_pointer_cast<SFTPHost>(Host::SharedPtr()); }

private:
    struct AutoConnectionReturn;

    static void SpawnSSH2_KbdCallback(const char *name,
                                      int name_len,
                                      const char *instruction,
                                      int instruction_len,
                                      int num_prompts,
                                      const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
                                      LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses,
                                      void **abstract);
    int DoInit();
    int SpawnSSH2(std::unique_ptr<Connection> &_t);
    static int SpawnSFTP(std::unique_ptr<Connection> &_t);

    in_addr_t InetAddr() const;
    const class SFTPHostConfiguration &Config() const;

    std::vector<std::unique_ptr<Connection>> m_Connections;
    std::mutex m_ConnectionsLock;
    VFSConfiguration m_Config;
    std::string m_HomeDir;
    in_addr_t m_HostAddr = 0;
    bool m_ReversedSymlinkParameters = false;
    sftp::OSType m_OSType = sftp::OSType::Unknown;
};

} // namespace nc::vfs
