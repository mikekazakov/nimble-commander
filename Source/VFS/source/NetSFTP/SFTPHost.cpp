// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/algo.h>
#include <Utility/PathManip.h>
#include <libssh2.h>
#include <libssh2_sftp.h>
#include "../ListingInput.h"
#include "SFTPHost.h"
#include "File.h"
#include "Errors.h"
#include "OSDetector.h"
#include "AccountsFetcher.h"
#include <sys/socket.h>
#include <sys/param.h>
#include <netdb.h>
#include <thread>
#include <Base/spinlock.h>
#include <sys/dirent.h>

// libssh2 is full of macros with C-style casts, hence disabling here
#pragma clang diagnostic ignored "-Wold-style-cast"

namespace nc::vfs {

using namespace std::literals;
using sftp::ErrorDomain;
using sftp::Errors;

static bool ServerHasReversedSymlinkParameters(LIBSSH2_SESSION *_session);

SFTPHost::Connection::~Connection()
{
    if( sftp ) {
        libssh2_sftp_shutdown(sftp);
        sftp = nullptr;
    }

    if( ssh ) {
        libssh2_session_disconnect_ex(ssh, SSH_DISCONNECT_BY_APPLICATION, "Farewell from Nimble Commander!", "");
        libssh2_session_free(ssh);
        ssh = nullptr;
    }

    if( socket >= 0 ) {
        close(socket);
        socket = -1;
    }
}

bool SFTPHost::Connection::Alive() const
{
    const auto socket_ok = [&] {
        int error = 0;
        socklen_t len = sizeof(error);
        const int retval = getsockopt(socket, SOL_SOCKET, SO_ERROR, &error, &len);
        return retval == 0 && error == 0;
    }();

    const auto last_errno = libssh2_session_last_errno(ssh);
    const auto session_ok = last_errno == LIBSSH2_ERROR_NONE || last_errno == LIBSSH2_ERROR_SFTP_PROTOCOL;
    return socket_ok && session_ok;
}

struct SFTPHost::AutoConnectionReturn // classic RAII stuff to prevent connections leaking in
                                      // operations
{
    AutoConnectionReturn(std::unique_ptr<Connection> &_conn, SFTPHost *_this) : m_Conn(_conn), m_This(_this)
    {
        assert(_conn != nullptr);
        assert(_this != nullptr);
    }

    ~AutoConnectionReturn() { m_This->ReturnConnection(std::move(m_Conn)); }
    std::unique_ptr<Connection> &m_Conn;
    SFTPHost *m_This;
};

const char *SFTPHost::UniqueTag = "net_sftp";

class SFTPHostConfiguration
{
public:
    std::string server_url;
    std::string user;
    std::string passwd;
    std::string keypath;
    std::string verbose; // cached only. not counted in operator ==
    long port;
    std::string home; // optional ftp ssh servers, mandatory for sftp-only servers

    [[nodiscard]] static const char *Tag() { return SFTPHost::UniqueTag; }

    [[nodiscard]] const char *Junction() const { return server_url.c_str(); }

    bool operator==(const SFTPHostConfiguration &_rhs) const
    {
        return server_url == _rhs.server_url && user == _rhs.user && passwd == _rhs.passwd && keypath == _rhs.keypath &&
               port == _rhs.port && home == _rhs.home;
    }

    [[nodiscard]] const char *VerboseJunction() const { return verbose.c_str(); }
};

VFSConfiguration SFTPHost::Configuration() const
{
    return m_Config;
}

VFSMeta SFTPHost::Meta()
{
    VFSMeta m;
    m.Tag = UniqueTag;
    m.SpawnWithConfig = []([[maybe_unused]] const VFSHostPtr &_parent,
                           const VFSConfiguration &_config,
                           [[maybe_unused]] VFSCancelChecker _cancel_checker) {
        return std::make_shared<SFTPHost>(_config);
    };
    m.error_domain = sftp::ErrorDomain;
    m.error_description_provider = std::make_shared<sftp::ErrorDescriptionProvider>();
    return m;
}

SFTPHost::SFTPHost(const VFSConfiguration &_config)
    : Host(_config.Get<SFTPHostConfiguration>().server_url, nullptr, UniqueTag), m_Config(_config)
{
    const int rc = DoInit();
    if( rc < 0 )
        throw ErrorException(VFSError::ToError(rc));
}

static VFSConfiguration ComposeConfguration(const std::string &_serv_url,
                                            const std::string &_user,
                                            const std::string &_passwd,
                                            const std::string &_keypath,
                                            long _port,
                                            const std::string &_home)
{
    SFTPHostConfiguration config;
    config.server_url = _serv_url;
    config.user = _user;
    config.passwd = _passwd;
    config.keypath = _keypath;
    config.port = _port;
    config.verbose = "sftp://"s + config.user + "@" + config.server_url;
    config.home = _home;
    return {std::move(config)};
}

SFTPHost::SFTPHost(const std::string &_serv_url,
                   const std::string &_user,
                   const std::string &_passwd,
                   const std::string &_keypath,
                   long _port,
                   const std::string &_home)
    : Host(_serv_url, nullptr, UniqueTag),
      m_Config(ComposeConfguration(_serv_url, _user, _passwd, _keypath, _port, _home))
{
    const int rc = DoInit();
    if( rc < 0 )
        throw ErrorException(VFSError::ToError(rc));
}

int SFTPHost::DoInit()
{
    static std::once_flag once;
    call_once(once, [] {
        const int rc = libssh2_init(0);
        assert(rc == 0);
        if( rc != 0 )
            throw std::runtime_error("libssh2_init failed");
    });

    struct hostent *remote_host = gethostbyname(Config().server_url.c_str());
    if( !remote_host )
        return VFSError::NetSFTPCouldntResolveHost; // need something meaningful
    if( remote_host->h_addrtype != AF_INET )
        return VFSError::NetSFTPCouldntResolveHost; // need something meaningful
    m_HostAddr = *reinterpret_cast<in_addr_t *>(remote_host->h_addr_list[0]);

    std::unique_ptr<Connection> conn;
    int rc = SpawnSSH2(conn);
    if( rc != 0 )
        return rc;

    m_ReversedSymlinkParameters = ServerHasReversedSymlinkParameters(conn->ssh);

    rc = SpawnSFTP(conn);
    if( rc < 0 )
        return rc;

    m_OSType = sftp::OSDetector{conn->ssh}.Detect();

    if( !Config().home.empty() ) {
        // user specified an initial path - just use it
        m_HomeDir = Config().home;
    }
    else {
        // firstly try to simulate "pwd" by using readlink() on relative "." path using regular sftp
        char buffer[MAXPATHLEN];
        rc = libssh2_sftp_realpath(conn->sftp, ".", buffer, MAXPATHLEN);
        if( rc >= 0 && buffer[0] == '/' ) {
            m_HomeDir = buffer;
        }
        else {
            // otherwise - use workaround with ssh commands execution - exec "pwd" on remote server.
            // this will not work on sftp-only servers (with ssh disabled)
            LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(conn->ssh);
            if( channel == nullptr )
                return VFSError::NetSFTPErrorSSH;

            rc = libssh2_channel_exec(channel, "pwd");
            if( rc < 0 ) {
                libssh2_channel_close(channel);
                libssh2_channel_free(channel);
                return VFSError::NetSFTPErrorSSH;
            }

            rc = (int)libssh2_channel_read(channel, buffer, sizeof(buffer));
            libssh2_channel_close(channel);
            libssh2_channel_free(channel);

            if( rc <= 0 )
                return VFSError::NetSFTPErrorSSH;
            buffer[rc - 1] = 0;

            m_HomeDir = buffer;
        }
    }

    ReturnConnection(std::move(conn));

    AddFeatures(HostFeatures::SetOwnership | HostFeatures::SetPermissions | HostFeatures::SetTimes);
    if( m_OSType != sftp::OSType::Unknown )
        AddFeatures(HostFeatures::FetchUsers | HostFeatures::FetchGroups);

    return 0;
}

const class SFTPHostConfiguration &SFTPHost::Config() const
{
    return m_Config.GetUnchecked<SFTPHostConfiguration>();
}

const std::string &SFTPHost::HomeDir() const
{
    return m_HomeDir;
}

void SFTPHost::SpawnSSH2_KbdCallback([[maybe_unused]] const char *name,
                                     [[maybe_unused]] int name_len,
                                     [[maybe_unused]] const char *instruction,
                                     [[maybe_unused]] int instruction_len,
                                     int num_prompts,
                                     [[maybe_unused]] const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
                                     LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses,
                                     void **abstract)
{
    SFTPHost *_this = *(SFTPHost **)abstract;
    if( num_prompts == 1 ) {
        responses[0].text = strdup(_this->Config().passwd.c_str());
        responses[0].length = (unsigned)_this->Config().passwd.length();
    }
}

int SFTPHost::SpawnSSH2(std::unique_ptr<Connection> &_t)
{
    _t = nullptr;
    auto connection = std::make_unique<Connection>();

    int rc;

    const in_addr_t hostaddr = InetAddr();
    connection->socket = socket(AF_INET, SOCK_STREAM, 0);
    sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_port = htons(Config().port > 0 ? Config().port : 22);
    sin.sin_addr.s_addr = hostaddr;
    if( connect(connection->socket, (struct sockaddr *)(&sin), sizeof(struct sockaddr_in)) != 0 )
        return VFSError::NetSFTPCouldntConnect;

    int optval = 1;
    setsockopt(connection->socket, SOL_SOCKET, SO_KEEPALIVE, &optval, sizeof(optval));
    setsockopt(connection->socket, SOL_SOCKET, SO_NOSIGPIPE, &optval, sizeof(optval));

    /** This is a horrable line of code, but for unknown reason libssh2_session_handshake()
     * sporadically returns LIBSSH2_ERROR_TIMEOUT if it starts negotiation right after connect(). */
    std::this_thread::sleep_for(1ms);

    connection->ssh = libssh2_session_init_ex(nullptr, nullptr, nullptr, this);
    if( !connection->ssh )
        return VFSError::GenericError;

    rc = libssh2_session_handshake(connection->ssh, connection->socket);
    if( rc )
        return VFSError::NetSFTPCouldntEstablishSSH;

    if( !Config().keypath.empty() ) {
        rc = libssh2_userauth_publickey_fromfile_ex(connection->ssh,
                                                    Config().user.c_str(),
                                                    (unsigned)Config().user.length(),
                                                    nullptr,
                                                    Config().keypath.c_str(),
                                                    Config().passwd.c_str());
        if( rc ) {
            if( rc == LIBSSH2_ERROR_FILE )
                return VFSError::NetSFTPCouldntReadKey;
            else
                return VFSError::NetSFTPCouldntAuthenticateKey;
        }
    }
    else {
        char *authlist =
            libssh2_userauth_list(connection->ssh, Config().user.c_str(), (unsigned)Config().user.length());
        const bool has_keyboard_interactive =
            authlist != nullptr && strstr(authlist, "keyboard-interactive") != nullptr;

        int ret = LIBSSH2_ERROR_AUTHENTICATION_FAILED;
        if( has_keyboard_interactive ) // if supported - use keyboard interactive first
            ret = libssh2_userauth_keyboard_interactive_ex(
                connection->ssh, Config().user.c_str(), (unsigned)Config().user.length(), &SpawnSSH2_KbdCallback);
        if( ret ) // if no luck - use just password
            ret = libssh2_userauth_password_ex(connection->ssh,
                                               Config().user.c_str(),
                                               (unsigned)Config().user.length(),
                                               Config().passwd.c_str(),
                                               (unsigned)Config().passwd.length(),
                                               nullptr);
        if( ret )
            return VFSError::NetSFTPCouldntAuthenticatePassword;
    }

    _t = std::move(connection);

    return 0;
}

int SFTPHost::SpawnSFTP(std::unique_ptr<Connection> &_t)
{
    _t->sftp = libssh2_sftp_init(_t->ssh);

    if( !_t->sftp )
        return VFSError::NetSFTPCouldntInitSFTP;

    return 0;
}

int SFTPHost::GetConnection(std::unique_ptr<Connection> &_t)
{
    {
        const auto lock = std::lock_guard{m_ConnectionsLock};
        while( !m_Connections.empty() ) {
            auto connection = std::move(m_Connections.front());
            m_Connections.erase(begin(m_Connections));

            // if front connection is fine - return it
            if( connection->Alive() ) {
                _t = std::move(connection);
                return 0;
            }
            // otherwise this connection object will be destroyed.
        }
    }

    const int rc = SpawnSSH2(_t);
    if( rc < 0 )
        return rc;

    return SpawnSFTP(_t);
}

void SFTPHost::ReturnConnection(std::unique_ptr<Connection> _t)
{
    if( !_t->Alive() )
        return;

    const std::lock_guard<std::mutex> lock(m_ConnectionsLock);

    m_Connections.emplace_back(std::move(_t));
}

in_addr_t SFTPHost::InetAddr() const
{
    return m_HostAddr;
}

std::expected<VFSListingPtr, Error>
SFTPHost::FetchDirectoryListing(std::string_view _path,
                                unsigned long _flags,
                                [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if( rc )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    // setup of listing structure
    using nc::base::variable_container;
    ListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(std::string(_path));
    listing_source.sizes.reset(variable_container<>::type::dense);
    listing_source.uids.reset(variable_container<>::type::dense);
    listing_source.gids.reset(variable_container<>::type::dense);
    listing_source.atimes.reset(variable_container<>::type::dense);
    listing_source.mtimes.reset(variable_container<>::type::dense);
    listing_source.ctimes.reset(variable_container<>::type::dense);
    listing_source.btimes.reset(variable_container<>::type::dense);
    listing_source.symlinks.reset(variable_container<>::type::sparse);

    {
        // fetch listing using readdir
        LIBSSH2_SFTP_HANDLE *sftp_handle = libssh2_sftp_open_ex(
            conn->sftp, _path.data(), static_cast<unsigned>(_path.length()), 0, 0, LIBSSH2_SFTP_OPENDIR);
        if( !sftp_handle )
            return std::unexpected(VFSError::ToError(VFSErrorForConnection(*conn)));
        auto close_sftp_handle = at_scope_end([=] { libssh2_sftp_closedir(sftp_handle); });

        const bool should_have_dot_dot = !(_flags & VFSFlags::F_NoDotDot) && listing_source.directories[0] != "/";
        if( should_have_dot_dot ) {
            // create space for dot-dot entry in advance
            listing_source.filenames.emplace_back("..");
            listing_source.unix_modes.emplace_back(S_IFDIR | S_IRWXU);
            listing_source.unix_types.emplace_back(DT_DIR);
        }

        char filename[MAXPATHLEN];
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        while( libssh2_sftp_readdir_ex(sftp_handle, filename, sizeof(filename), nullptr, 0, &attrs) > 0 ) {
            int index = 0;
            if( filename == std::string_view{"."} )
                continue;                                   // do not process self entry
            else if( filename == std::string_view{".."} ) { // special case for dot-dot directory
                if( !should_have_dot_dot )
                    continue; // skip .. for root directory or if there's an option to exclude
                              // dot-dot entries
            }
            else { // all other cases
                listing_source.filenames.emplace_back();
                listing_source.unix_modes.emplace_back();
                listing_source.unix_types.emplace_back();
                index = int(listing_source.filenames.size() - 1);
            }

            const bool has_perm = (attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS);
            listing_source.filenames[index] = filename;
            listing_source.unix_modes[index] = has_perm ? mode_t(attrs.permissions) : (S_IFREG | S_IRUSR);
            listing_source.unix_types[index] = has_perm ? IFTODT(attrs.permissions) : DT_REG;
            const auto size = S_ISDIR(attrs.permissions)
                                  ? ListingInput::unknown_size
                                  : ((attrs.flags & LIBSSH2_SFTP_ATTR_SIZE) ? attrs.filesize : 0);
            listing_source.sizes.insert(index, size);
            listing_source.uids.insert(index, (attrs.flags & LIBSSH2_SFTP_ATTR_UIDGID) ? (uid_t)attrs.uid : 0);
            listing_source.gids.insert(index, (attrs.flags & LIBSSH2_SFTP_ATTR_UIDGID) ? (uid_t)attrs.gid : 0);
            listing_source.atimes.insert(index, (attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) ? attrs.atime : 0);
            listing_source.mtimes.insert(index, (attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) ? attrs.mtime : 0);
            listing_source.btimes.insert(index, (attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) ? attrs.mtime : 0);
            listing_source.ctimes.insert(index, (attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) ? attrs.mtime : 0);
        }
    }

    // check for symlinks and read additional info
    for( int index = 0, index_e = (int)listing_source.filenames.size(); index != index_e; ++index )
        if( listing_source.unix_types[index] == DT_LNK ) {
            const std::string path = listing_source.directories[0] + listing_source.filenames[index];

            // read where symlink points at
            char symlink[MAXPATHLEN];
            rc = libssh2_sftp_symlink_ex(
                conn->sftp, path.c_str(), (unsigned)path.length(), symlink, MAXPATHLEN, LIBSSH2_SFTP_READLINK);
            if( rc >= 0 )
                listing_source.symlinks.insert(index, symlink);

            // read info about real object
            LIBSSH2_SFTP_ATTRIBUTES stat;
            if( libssh2_sftp_stat_ex(conn->sftp, path.c_str(), (unsigned)path.length(), LIBSSH2_SFTP_STAT, &stat) >=
                0 ) {
                listing_source.unix_modes[index] = mode_t(stat.permissions);
                listing_source.sizes.insert(index, stat.filesize);
            }
        }

    return VFSListing::Build(std::move(listing_source));
}

std::expected<VFSStat, Error>
SFTPHost::Stat(std::string_view _path, unsigned long _flags, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if( rc )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    LIBSSH2_SFTP_ATTRIBUTES attrs;
    rc = libssh2_sftp_stat_ex(conn->sftp,
                              _path.data(),
                              static_cast<unsigned>(_path.length()),
                              (_flags & VFSFlags::F_NoFollow) ? LIBSSH2_SFTP_LSTAT : LIBSSH2_SFTP_STAT,
                              &attrs);
    if( rc )
        return std::unexpected(VFSError::ToError(VFSErrorForConnection(*conn)));

    VFSStat st;

    if( attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS ) {
        st.mode = mode_t(attrs.permissions);
        st.meaning.mode = 1;
    }

    if( attrs.flags & LIBSSH2_SFTP_ATTR_UIDGID ) {
        st.uid = (uid_t)attrs.uid;
        st.gid = (gid_t)attrs.gid;
        st.meaning.uid = 1;
        st.meaning.gid = 1;
    }

    if( attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME ) {
        st.atime.tv_sec = attrs.atime;
        st.mtime.tv_sec = attrs.mtime;
        st.ctime.tv_sec = attrs.mtime;
        st.btime.tv_sec = attrs.mtime;
        st.meaning.atime = 1;
        st.meaning.mtime = 1;
        st.meaning.ctime = 1;
        st.meaning.btime = 1;
    }

    if( attrs.flags & LIBSSH2_SFTP_ATTR_SIZE ) {
        st.size = attrs.filesize;
        st.meaning.size = 1;
    }

    return st;
}

std::expected<void, Error>
SFTPHost::IterateDirectoryListing(std::string_view _path, const std::function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    std::unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if( rc )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    LIBSSH2_SFTP_HANDLE *sftp_handle = libssh2_sftp_open_ex(
        conn->sftp, _path.data(), static_cast<unsigned>(_path.length()), 0, 0, LIBSSH2_SFTP_OPENDIR);
    if( !sftp_handle ) {
        return std::unexpected(VFSError::ToError(VFSErrorForConnection(*conn)));
    }
    const auto close_sftp_handle = at_scope_end([&] { libssh2_sftp_closedir(sftp_handle); });

    VFSDirEnt e;
    while( true ) {
        char mem[MAXPATHLEN];
        LIBSSH2_SFTP_ATTRIBUTES attrs;

        /* loop until we fail */
        rc = libssh2_sftp_readdir_ex(sftp_handle, mem, sizeof(mem), nullptr, 0, &attrs);
        if( rc <= 0 )
            break;

        if( mem[0] == '.' && mem[1] == 0 )
            continue;
        if( mem[0] == '.' && mem[1] == '.' && mem[2] == 0 )
            continue;

        if( !(attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) )
            break; // can't process without meanful mode

        strcpy(e.name, mem);
        e.name_len = uint16_t(strlen(mem));
        e.type = IFTODT(attrs.permissions);

        if( !_handler(e) )
            break;
    }

    return {};
}

std::expected<VFSStatFS, Error> SFTPHost::StatFS(std::string_view _path,
                                                 [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if( rc )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    LIBSSH2_SFTP_STATVFS statfs;
    rc = libssh2_sftp_statvfs(conn->sftp, _path.data(), _path.length(), &statfs);
    if( rc < 0 )
        return std::unexpected(VFSError::ToError(VFSErrorForConnection(*conn)));

    VFSStatFS stat;
    stat.total_bytes = statfs.f_blocks * statfs.f_frsize;
    stat.avail_bytes = statfs.f_bavail * statfs.f_frsize;
    stat.free_bytes = statfs.f_ffree * statfs.f_frsize;
    return stat;
}

std::expected<std::shared_ptr<VFSFile>, Error> SFTPHost::CreateFile(std::string_view _path,
                                                                    const VFSCancelChecker &_cancel_checker)
{
    auto file = std::make_shared<sftp::File>(_path, SharedPtr());
    if( _cancel_checker && _cancel_checker() )
        return std::unexpected(Error{Error::POSIX, ECANCELED});
    return file;
}

bool SFTPHost::IsWritable() const
{
    return true; // dummy now
}

std::expected<void, Error> SFTPHost::Unlink(std::string_view _path,
                                            [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if( rc )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    rc = libssh2_sftp_unlink_ex(conn->sftp, _path.data(), static_cast<unsigned>(_path.length()));

    if( rc < 0 )
        return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));

    return {};
}

std::expected<void, Error>
SFTPHost::Rename(std::string_view _old_path, std::string_view _new_path, const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    if( const int rc = GetConnection(conn); rc != VFSError::Ok )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    const auto rename_flags = LIBSSH2_SFTP_RENAME_OVERWRITE | LIBSSH2_SFTP_RENAME_ATOMIC | LIBSSH2_SFTP_RENAME_NATIVE;
    const auto rename_rc = libssh2_sftp_rename_ex(conn->sftp,
                                                  _old_path.data(),
                                                  static_cast<unsigned>(_old_path.length()),
                                                  _new_path.data(),
                                                  static_cast<unsigned>(_new_path.length()),
                                                  rename_flags);
    if( rename_rc == LIBSSH2_ERROR_NONE )
        return {};

    const auto rename_vfs_rc = ErrorForConnection(*conn);

    if( rename_rc == LIBSSH2_ERROR_SFTP_PROTOCOL && libssh2_sftp_last_error(conn->sftp) == LIBSSH2_FX_FAILURE &&
        Exists(_new_path, _cancel_checker) ) {
        // it's likely that a SSH server forbids a direct usage of overwriting semantics
        // lets try to fallback to "rm + mv" scheme
        if( const std::expected<void, Error> unlink_rc = Unlink(_new_path, _cancel_checker); !unlink_rc )
            return unlink_rc;

        const auto rename2_rc = libssh2_sftp_rename_ex(conn->sftp,
                                                       _old_path.data(),
                                                       static_cast<unsigned>(_old_path.length()),
                                                       _new_path.data(),
                                                       static_cast<unsigned>(_new_path.length()),
                                                       rename_flags);
        if( rename2_rc == LIBSSH2_ERROR_NONE )
            return {};

        return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));
    }

    return std::unexpected(rename_vfs_rc.value_or(Error{ErrorDomain, Errors::sftp_protocol}));
}

std::expected<void, Error> SFTPHost::RemoveDirectory(std::string_view _path,
                                                     [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if( rc != VFSError::Ok )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    rc = libssh2_sftp_rmdir_ex(conn->sftp, _path.data(), static_cast<unsigned>(_path.length()));

    if( rc < 0 )
        return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));

    return {};
}

std::expected<void, Error>
SFTPHost::CreateDirectory(std::string_view _path, int _mode, [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if( rc )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    rc = libssh2_sftp_mkdir_ex(conn->sftp, _path.data(), static_cast<unsigned>(_path.length()), _mode);

    if( rc < 0 )
        return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));

    return {};
}

// TODO: remove this
int SFTPHost::VFSErrorForConnection(Connection &_conn)
{
    using namespace VFSError;
    const int sess_errno = libssh2_session_last_errno(_conn.ssh);
    if( sess_errno == 0 )
        return 0;
    if( sess_errno == LIBSSH2_ERROR_SFTP_PROTOCOL )
        switch( libssh2_sftp_last_error(_conn.sftp) ) {
            case LIBSSH2_FX_OK:
                return 0;
            case LIBSSH2_FX_EOF:
                return NetSFTPEOF;
            case LIBSSH2_FX_NO_SUCH_FILE:
                return NetSFTPNoSuchFile;
            case LIBSSH2_FX_PERMISSION_DENIED:
                return NetSFTPPermissionDenied;
            case LIBSSH2_FX_FAILURE:
                return NetSFTPFailure;
            case LIBSSH2_FX_BAD_MESSAGE:
                return NetSFTPBadMessage;
            case LIBSSH2_FX_NO_CONNECTION:
                return NetSFTPNoConnection;
            case LIBSSH2_FX_CONNECTION_LOST:
                return NetSFTPConnectionLost;
            case LIBSSH2_FX_OP_UNSUPPORTED:
                return NetSFTPOpUnsupported;
            case LIBSSH2_FX_INVALID_HANDLE:
                return NetSFTPInvalidHandle;
            case LIBSSH2_FX_NO_SUCH_PATH:
                return NetSFTPNoSuchPath;
            case LIBSSH2_FX_FILE_ALREADY_EXISTS:
                return NetSFTPFileAlreadyExists;
            case LIBSSH2_FX_WRITE_PROTECT:
                return NetSFTPWriteProtect;
            case LIBSSH2_FX_NO_MEDIA:
                return NetSFTPNoMedia;
            case LIBSSH2_FX_NO_SPACE_ON_FILESYSTEM:
                return NetSFTPNoSpaceOnFilesystem;
            case LIBSSH2_FX_QUOTA_EXCEEDED:
                return NetSFTPQuotaExceeded;
            case LIBSSH2_FX_UNKNOWN_PRINCIPAL:
                return NetSFTPUnknownPrincipal;
            case LIBSSH2_FX_LOCK_CONFLICT:
                return NetSFTPLockConflict;
            case LIBSSH2_FX_DIR_NOT_EMPTY:
                return NetSFTPDirNotEmpty;
            case LIBSSH2_FX_NOT_A_DIRECTORY:
                return NetSFTPNotADir;
            case LIBSSH2_FX_INVALID_FILENAME:
                return NetSFTPInvalidFilename;
            case LIBSSH2_FX_LINK_LOOP:
                return NetSFTPLinkLoop;
            default:
                return NetSFTPFailure;
        }
    return NetSFTPErrorSSH; // until the better times we dont have a better errors explanation
}

std::optional<Error> SFTPHost::ErrorForConnection(Connection &_conn)
{
    if( const int sess_errno = libssh2_session_last_errno(_conn.ssh); sess_errno != 0 ) {
        if( sess_errno == LIBSSH2_ERROR_SFTP_PROTOCOL )
            return Error{sftp::ErrorDomain, static_cast<int64_t>(libssh2_sftp_last_error(_conn.sftp))};
        else
            return Error{sftp::ErrorDomain, static_cast<int64_t>(sess_errno)};
    }
    return {};
}

const std::string &SFTPHost::ServerUrl() const noexcept
{
    return Config().server_url;
}

const std::string &SFTPHost::User() const noexcept
{
    return Config().user;
}

const std::string &SFTPHost::Keypath() const noexcept
{
    return Config().keypath;
}

long SFTPHost::Port() const noexcept
{
    return Config().port;
}

std::expected<std::string, Error> SFTPHost::ReadSymlink(std::string_view _symlink_path,
                                                        [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    if( const int rc = GetConnection(conn); rc < 0 )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    char buffer[4096];
    const int readlink_rc = libssh2_sftp_symlink_ex(conn->sftp,
                                                    _symlink_path.data(),
                                                    static_cast<unsigned>(_symlink_path.length()),
                                                    buffer,
                                                    sizeof(buffer) - 1,
                                                    LIBSSH2_SFTP_READLINK);
    if( readlink_rc >= 0 ) {
        return std::string(buffer, readlink_rc);
    }
    else {
        return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));
    }
}

std::expected<void, Error> SFTPHost::CreateSymlink(std::string_view _symlink_path,
                                                   std::string_view _symlink_value,
                                                   [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    if( const int rc = GetConnection(conn); rc < 0 )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    const auto symlink_rc = m_ReversedSymlinkParameters
                                ? libssh2_sftp_symlink_ex(conn->sftp,
                                                          _symlink_value.data(),
                                                          static_cast<unsigned>(_symlink_value.length()),
                                                          (char *)_symlink_path.data(),
                                                          static_cast<unsigned>(_symlink_path.length()),
                                                          LIBSSH2_SFTP_SYMLINK)
                                : libssh2_sftp_symlink_ex(conn->sftp,
                                                          _symlink_path.data(),
                                                          static_cast<unsigned>(_symlink_path.length()),
                                                          (char *)_symlink_value.data(),
                                                          static_cast<unsigned>(_symlink_value.length()),
                                                          LIBSSH2_SFTP_SYMLINK);
    if( symlink_rc == 0 )
        return {};
    else
        return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));
}

std::expected<void, Error> SFTPHost::SetPermissions(std::string_view _path,
                                                    uint16_t _mode,
                                                    [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    if( const int rc = GetConnection(conn); rc < 0 )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    LIBSSH2_SFTP_ATTRIBUTES attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.flags = LIBSSH2_SFTP_ATTR_PERMISSIONS;
    attrs.permissions = _mode;

    const auto rc = libssh2_sftp_stat_ex(
        conn->sftp, _path.data(), static_cast<unsigned>(_path.length()), LIBSSH2_SFTP_SETSTAT, &attrs);
    if( rc == 0 )
        return {};
    else
        return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));
}

std::expected<void, Error> SFTPHost::SetOwnership(std::string_view _path,
                                                  unsigned _uid,
                                                  unsigned _gid,
                                                  [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    std::unique_ptr<Connection> conn;
    if( const int rc = GetConnection(conn); rc < 0 )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    LIBSSH2_SFTP_ATTRIBUTES attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.flags = LIBSSH2_SFTP_ATTR_UIDGID;
    attrs.uid = _uid;
    attrs.gid = _gid;

    const int rc = libssh2_sftp_stat_ex(
        conn->sftp, _path.data(), static_cast<unsigned>(_path.length()), LIBSSH2_SFTP_SETSTAT, &attrs);
    if( rc == 0 )
        return {};
    else
        return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));
}

std::expected<void, Error> SFTPHost::SetTimes(std::string_view _path,
                                              std::optional<time_t> _birth_time,
                                              std::optional<time_t> _mod_time,
                                              std::optional<time_t> _chg_time,
                                              std::optional<time_t> _acc_time,
                                              [[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    _birth_time = std::nullopt;
    _chg_time = std::nullopt;

    if( !_birth_time && !_mod_time && !_chg_time && !_acc_time )
        return {};

    std::unique_ptr<Connection> conn;
    if( const int rc = GetConnection(conn); rc < 0 )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    if( !_mod_time || !_acc_time ) {
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        const int rc = libssh2_sftp_stat_ex(
            conn->sftp, _path.data(), static_cast<unsigned>(_path.length()), LIBSSH2_SFTP_LSTAT, &attrs);
        if( rc != 0 )
            return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));

        if( attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME ) {
            if( !_mod_time )
                _mod_time = attrs.mtime;
            if( !_acc_time )
                _acc_time = attrs.atime;
        }
        else
            return std::unexpected(nc::Error{nc::Error::POSIX, ENOTSUP});
    }

    LIBSSH2_SFTP_ATTRIBUTES attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.flags = LIBSSH2_SFTP_ATTR_ACMODTIME;
    attrs.atime = *_acc_time;
    attrs.mtime = *_mod_time;

    const auto rc = libssh2_sftp_stat_ex(
        conn->sftp, _path.data(), static_cast<unsigned>(_path.length()), LIBSSH2_SFTP_SETSTAT, &attrs);
    if( rc == 0 )
        return {};
    else
        return std::unexpected(ErrorForConnection(*conn).value_or(Error{ErrorDomain, Errors::sftp_protocol}));
}

std::expected<std::vector<VFSUser>, Error>
SFTPHost::FetchUsers([[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( m_OSType == sftp::OSType::Unknown )
        return std::unexpected(Error{Error::POSIX, ENODEV});

    std::unique_ptr<Connection> conn;
    if( const int rc = GetConnection(conn); rc < 0 )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    sftp::AccountsFetcher fetcher{conn->ssh, m_OSType};
    return fetcher.FetchUsers();
}

std::expected<std::vector<VFSGroup>, Error>
SFTPHost::FetchGroups([[maybe_unused]] const VFSCancelChecker &_cancel_checker)
{
    if( m_OSType == sftp::OSType::Unknown )
        return std::unexpected(Error{Error::POSIX, ENODEV});

    std::unique_ptr<Connection> conn;
    if( const int rc = GetConnection(conn); rc < 0 )
        return std::unexpected(VFSError::ToError(rc));

    const AutoConnectionReturn acr(conn, this);

    sftp::AccountsFetcher fetcher{conn->ssh, m_OSType};
    return fetcher.FetchGroups();
}

static bool ServerHasReversedSymlinkParameters(LIBSSH2_SESSION *_session)
{
    const auto banner = libssh2_session_banner_get(_session);
    return banner && (strstr(banner, "OpenSSH") || strstr(banner, "mod_sftp"));
}

} // namespace nc::vfs
