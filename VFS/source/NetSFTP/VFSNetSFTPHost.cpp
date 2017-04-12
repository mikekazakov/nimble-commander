//
//  VFSNetSFTPHost.mm
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/algo.h>
#include <Utility/PathManip.h>
#include <libssh2.h>
#include <libssh2_sftp.h>
#include "../VFSListingInput.h"
#include "VFSNetSFTPHost.h"
#include "VFSNetSFTPFile.h"

VFSNetSFTPHost::Connection::~Connection()
{
    if(sftp) {
        libssh2_sftp_shutdown(sftp);
        sftp = nullptr;
    }
    
    if(ssh) {
        libssh2_session_disconnect(ssh, "Farewell from Nimble Commander!");
        libssh2_session_free(ssh);
        ssh = nullptr;
    }
    
    if(socket >= 0) {
        close(socket);
        socket = -1;
    }
}

bool VFSNetSFTPHost::Connection::Alive() const
{
    const auto socket_ok = [&]{
        int error = 0;
        socklen_t len = sizeof(error);
        int retval = getsockopt (socket, SOL_SOCKET, SO_ERROR, &error, &len );
        return retval == 0 && error == 0;
    }();
    
    const auto session_ok = libssh2_session_last_errno(ssh) == 0;
    
    return socket_ok && session_ok;
}

struct VFSNetSFTPHost::AutoConnectionReturn // classic RAII stuff to prevent connections leaking in operations
{
    inline AutoConnectionReturn(unique_ptr<Connection> &_conn, VFSNetSFTPHost *_this):
        m_Conn(_conn),
        m_This(_this) {
        assert(_conn != nullptr);
        assert(_this != nullptr);
    }
    
    inline ~AutoConnectionReturn() {
        m_This->ReturnConnection(move(m_Conn));
    }
    unique_ptr<Connection> &m_Conn;
    VFSNetSFTPHost *m_This;
};

const char *VFSNetSFTPHost::Tag = "net_sftp";

class VFSNetSFTPHostConfiguration
{
public:
    string server_url;
    string user;
    string passwd;
    string keypath;
    string verbose; // cached only. not counted in operator ==
    long   port;
    string home; // optional ftp ssh servers, mandatory for sftp-only servers
    
    const char *Tag() const
    {
        return VFSNetSFTPHost::Tag;
    }
    
    const char *Junction() const
    {
        return server_url.c_str();
    }
    
    bool operator==(const VFSNetSFTPHostConfiguration&_rhs) const
    {
        return server_url == _rhs.server_url &&
               user       == _rhs.user &&
               passwd     == _rhs.passwd &&
               keypath    == _rhs.keypath &&
               port       == _rhs.port &&
               home       == _rhs.home;
    }
    
    const char *VerboseJunction() const
    {
        return verbose.c_str();
    }
};

VFSConfiguration VFSNetSFTPHost::Configuration() const
{
    return m_Config;
}

VFSMeta VFSNetSFTPHost::Meta()
{
    VFSMeta m;
    m.Tag = Tag;
    m.SpawnWithConfig = [](const VFSHostPtr &_parent, const VFSConfiguration& _config, VFSCancelChecker _cancel_checker) {
        return make_shared<VFSNetSFTPHost>(_config);
    };
    return m;
}

VFSNetSFTPHost::VFSNetSFTPHost(const VFSConfiguration &_config):
    VFSHost(_config.Get<VFSNetSFTPHostConfiguration>().server_url.c_str(), nullptr, Tag),
    m_Config(_config)
{
    int rc = DoInit();
    if(rc < 0)
        throw VFSErrorException(rc);
}

static VFSConfiguration ComposeConfguration(const string &_serv_url,
                                            const string &_user,
                                            const string &_passwd,
                                            const string &_keypath,
                                            long   _port,
                                            const string &_home)
{
    VFSNetSFTPHostConfiguration config;
    config.server_url = _serv_url;
    config.user = _user;
    config.passwd = _passwd;
    config.keypath = _keypath;
    config.port = _port;
    config.verbose = "sftp://"s + config.user + "@" + config.server_url;
    config.home = _home;
    return VFSConfiguration( move(config) );
}

VFSNetSFTPHost::VFSNetSFTPHost(const string &_serv_url,
                               const string &_user,
                               const string &_passwd,
                               const string &_keypath,
                               long   _port,
                               const string &_home):
    VFSHost(_serv_url.c_str(), nullptr, Tag),
    m_Config( ComposeConfguration(_serv_url, _user, _passwd, _keypath, _port, _home))
{    
    int rc = DoInit();
    if(rc < 0)
        throw VFSErrorException(rc);
}

int VFSNetSFTPHost::DoInit()
{
    static once_flag once;
    call_once(once, []{
        int rc = libssh2_init(0);
        assert(rc == 0);
    });

    struct hostent *remote_host = gethostbyname( Config().server_url.c_str() );
    if(!remote_host)
        return VFSError::NetSFTPCouldntResolveHost; // need something meaningful
    if(remote_host->h_addrtype != AF_INET)
        return VFSError::NetSFTPCouldntResolveHost; // need something meaningful
    m_HostAddr = *(in_addr_t *) remote_host->h_addr_list[0];
    
    unique_ptr<Connection> conn;
    int rc = SpawnSSH2(conn);
    if(rc != 0)
        return rc;
    
    rc = SpawnSFTP(conn);
    if(rc < 0)
        return rc;
    
    if( !Config().home.empty() ) {
        // user specified an initial path - just use it
        m_HomeDir = Config().home;
    }
    else {
        // firstly try to simulate "pwd" by using readlink() on relative "." path using regular sftp
        char buffer[MAXPATHLEN];
        rc = libssh2_sftp_realpath(conn->sftp, ".", buffer, MAXPATHLEN);
        if( rc >= 0  && buffer[0]=='/' ) {
            m_HomeDir = buffer;
        }
        else {
            // otherwise - use workaround with ssh commands execution - exec "pwd" on remote server. this will not work on sftp-only servers (with ssh disabled)
            LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(conn->ssh);
            if(channel == nullptr)
                return VFSError::NetSFTPErrorSSH;
            
            rc = libssh2_channel_exec(channel, "pwd");
            if(rc < 0) {
                libssh2_channel_close(channel);
                libssh2_channel_free(channel);
                return VFSError::NetSFTPErrorSSH;
            }
            
            rc = (int)libssh2_channel_read( channel, buffer, sizeof(buffer) );
            libssh2_channel_close(channel);
            libssh2_channel_free(channel);
            
            if( rc <= 0 )
                return VFSError::NetSFTPErrorSSH;
            buffer[rc - 1] = 0;
            
            m_HomeDir = buffer;
        }
    }
    
    ReturnConnection(move(conn));
    
    return 0;
}

const class VFSNetSFTPHostConfiguration &VFSNetSFTPHost::Config() const
{
    return m_Config.GetUnchecked<VFSNetSFTPHostConfiguration>();
}

const string& VFSNetSFTPHost::HomeDir() const
{
    return m_HomeDir;
}

void VFSNetSFTPHost::SpawnSSH2_KbdCallback(const char *name, int name_len,
                         const char *instruction, int instruction_len,
                         int num_prompts,
                         const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
                         LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses,
                         void **abstract)
{
    VFSNetSFTPHost *_this = *(VFSNetSFTPHost **)abstract;
    if (num_prompts == 1) {
        responses[0].text = strdup(_this->Config().passwd.c_str());
        responses[0].length = (unsigned)_this->Config().passwd.length();
    }
}

int VFSNetSFTPHost::SpawnSSH2(unique_ptr<Connection> &_t)
{
    _t = nullptr;
    auto connection = make_unique<Connection>();

    int rc;
    
    in_addr_t hostaddr = InetAddr();
    connection->socket = socket(AF_INET, SOCK_STREAM, 0);
    sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_port = htons(Config().port > 0 ? Config().port : 22);
    sin.sin_addr.s_addr = hostaddr;
    if (connect(connection->socket, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in)) != 0)
        return VFSError::NetSFTPCouldntConnect;
    
    int optval = 1;
    setsockopt(connection->socket, SOL_SOCKET, SO_KEEPALIVE, &optval, sizeof(optval));
	setsockopt(connection->socket, SOL_SOCKET, SO_NOSIGPIPE, &optval, sizeof(optval));

    connection->ssh = libssh2_session_init_ex(NULL, NULL, NULL, this);
    if(!connection->ssh)
        return VFSError::GenericError;
    
    rc = libssh2_session_handshake(connection->ssh, connection->socket);
    if(rc)
        return VFSError::NetSFTPCouldntEstablishSSH;
    
    if(!Config().keypath.empty()) {
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
        char *authlist = libssh2_userauth_list(connection->ssh, Config().user.c_str(), (unsigned)Config().user.length());
        bool has_keyboard_interactive = authlist != nullptr &&
                                        strstr(authlist, "keyboard-interactive") != nullptr;
        
        int ret = LIBSSH2_ERROR_AUTHENTICATION_FAILED;
        if( has_keyboard_interactive ) // if supported - use keyboard interactive first
            ret = libssh2_userauth_keyboard_interactive_ex(connection->ssh,
                                                           Config().user.c_str(),
                                                           (unsigned)Config().user.length(),
                                                           &SpawnSSH2_KbdCallback);
        if( ret ) // if no luck - use just password
            ret = libssh2_userauth_password_ex(connection->ssh,
                                               Config().user.c_str(),
                                               (unsigned)Config().user.length(),
                                               Config().passwd.c_str(),
                                               (unsigned)Config().passwd.length(),
                                               NULL);
        if ( ret )
            return VFSError::NetSFTPCouldntAuthenticatePassword;
    }
    
    _t = move(connection);
    
    return 0;
}

int VFSNetSFTPHost::SpawnSFTP(unique_ptr<Connection> &_t)
{    
    _t->sftp = libssh2_sftp_init(_t->ssh);
    
    if (!_t->sftp)
        return VFSError::NetSFTPCouldntInitSFTP;

    return 0;
}

int VFSNetSFTPHost::GetConnection(unique_ptr<Connection> &_t)
{
    LOCK_GUARD(m_ConnectionsLock) {
        while( !m_Connections.empty() ) {
            auto connection = move(m_Connections.front());
            m_Connections.erase( begin(m_Connections) );

            // if front connection is fine - return it
            if( connection->Alive() ) {
                _t = move(connection);
                return 0;
            }
            // otherwise this connection object will be destroyed.
        }
    }
    
    int rc = SpawnSSH2(_t);
    if(rc < 0)
        return rc;
    
    return SpawnSFTP(_t);
}

void VFSNetSFTPHost::ReturnConnection(unique_ptr<Connection> _t)
{
    if(!_t->Alive())
        return;
    
    lock_guard<mutex> lock(m_ConnectionsLock);

    m_Connections.emplace_back(move(_t));
}

in_addr_t VFSNetSFTPHost::InetAddr() const
{
    return m_HostAddr;
}

int VFSNetSFTPHost::FetchDirectoryListing(const char *_path,
                                          shared_ptr<VFSListing> &_target,
                                          int _flags,
                                          const VFSCancelChecker &_cancel_checker)
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return rc;
    
    AutoConnectionReturn acr(conn, this);
    
    // setup of listing structure
    VFSListingInput listing_source;
    listing_source.hosts[0] = shared_from_this();
    listing_source.directories[0] = EnsureTrailingSlash(_path);
    listing_source.sizes.reset( variable_container<>::type::dense );
    listing_source.uids.reset( variable_container<>::type::dense );
    listing_source.gids.reset( variable_container<>::type::dense );
    listing_source.atimes.reset( variable_container<>::type::dense );
    listing_source.mtimes.reset( variable_container<>::type::dense );
    listing_source.ctimes.reset( variable_container<>::type::dense );
    listing_source.btimes.reset( variable_container<>::type::dense );
    listing_source.symlinks.reset( variable_container<>::type::sparse );

    {
        // fetch listing using readdir
        LIBSSH2_SFTP_HANDLE *sftp_handle = libssh2_sftp_open_ex(conn->sftp, _path, (unsigned)strlen(_path), 0, 0, LIBSSH2_SFTP_OPENDIR);
        if( !sftp_handle )
            return VFSErrorForConnection(*conn);
        auto close_sftp_handle = at_scope_end([=]{ libssh2_sftp_closedir(sftp_handle); } );
        
        bool should_have_dot_dot = !(_flags & VFSFlags::F_NoDotDot) && listing_source.directories[0] != "/";
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
            if( strisdot(filename) )
                continue; // do not process self entry
            else if( strisdotdot(filename) ) { // special case for dot-dot directory
                if( !should_have_dot_dot )
                    continue; // skip .. for root directory or if there's an option to exclude dot-dot entries
            }
            else { // all other cases
                listing_source.filenames.emplace_back();
                listing_source.unix_modes.emplace_back();
                listing_source.unix_types.emplace_back();
                index = int(listing_source.filenames.size() - 1);
            }
            
            listing_source.filenames[index] = filename;
            listing_source.unix_modes[index] = (attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) ? attrs.permissions : (S_IFREG | S_IRUSR);
            listing_source.unix_types[index] = (attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) ? IFTODT(attrs.permissions) : DT_REG;
            listing_source.sizes.insert(index, (attrs.flags & LIBSSH2_SFTP_ATTR_SIZE) ? attrs.filesize : 0);
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
            string path = listing_source.directories[0] + listing_source.filenames[index];
        
            // read where symlink points at
            char symlink[MAXPATHLEN];
            rc = libssh2_sftp_symlink_ex(conn->sftp, path.c_str(), (unsigned)path.length(), symlink, MAXPATHLEN, LIBSSH2_SFTP_READLINK);
            if(rc >= 0)
                listing_source.symlinks.insert(index, symlink);
            
            // read info about real object
            LIBSSH2_SFTP_ATTRIBUTES stat;
            if(libssh2_sftp_stat_ex(conn->sftp, path.c_str(), (unsigned)path.length(), LIBSSH2_SFTP_STAT, &stat) >= 0) {
                listing_source.unix_modes[index] = stat.permissions;
                listing_source.sizes.insert(index, stat.filesize);
            }
        }
    
    _target = VFSListing::Build(move(listing_source));
    
    return 0;    
}

int VFSNetSFTPHost::Stat(const char *_path,
                         VFSStat &_st,
                         int _flags,
                         const VFSCancelChecker &_cancel_checker)
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return rc;
    
    AutoConnectionReturn acr(conn, this);
    

    LIBSSH2_SFTP_ATTRIBUTES attrs;
    rc = libssh2_sftp_stat_ex(conn->sftp,
                              _path,
                              (unsigned)strlen(_path),
                              (_flags & VFSFlags::F_NoFollow) ? LIBSSH2_SFTP_LSTAT : LIBSSH2_SFTP_STAT,
                              &attrs);
    if(rc)
        return VFSErrorForConnection(*conn);
    
    memset(&_st, 0, sizeof(_st));

    if(attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) {
        _st.mode = attrs.permissions;
        _st.meaning.mode = 1;
    }

    if(attrs.flags & LIBSSH2_SFTP_ATTR_UIDGID) {
        _st.uid = (uid_t)attrs.uid;
        _st.gid = (gid_t)attrs.gid;
        _st.meaning.uid = 1;
        _st.meaning.gid = 1;
    }

    if(attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) {
        _st.atime.tv_sec = attrs.atime;
        _st.mtime.tv_sec = attrs.mtime;
        _st.ctime.tv_sec = attrs.mtime;
        _st.btime.tv_sec = attrs.mtime;
        _st.meaning.atime = 1;
        _st.meaning.mtime = 1;
        _st.meaning.ctime = 1;
        _st.meaning.btime = 1;
    }
    
    if(attrs.flags & LIBSSH2_SFTP_ATTR_SIZE) {
        _st.size = attrs.filesize;
        _st.meaning.size = 1;
    }
    
    return 0;
}

int VFSNetSFTPHost::IterateDirectoryListing(const char *_path,
                                            const function<bool(const VFSDirEnt &_dirent)> &_handler)
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return rc;
    
    AutoConnectionReturn acr(conn, this);
    
    LIBSSH2_SFTP_HANDLE *sftp_handle = libssh2_sftp_open_ex(conn->sftp, _path, (unsigned)strlen(_path), 0, 0, LIBSSH2_SFTP_OPENDIR);
    if (!sftp_handle) {
        return VFSErrorForConnection(*conn);
    }
    
    VFSDirEnt e;
    while (true) {
        char mem[MAXPATHLEN];
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        
        /* loop until we fail */
        rc = libssh2_sftp_readdir_ex(sftp_handle, mem, sizeof(mem), nullptr, 0, &attrs);
        if(rc <= 0)
            break;
        
        if( mem[0] == '.' && mem[1] == 0 ) continue;
        if( mem[0] == '.' && mem[1] == '.' && mem[2] == 0 ) continue;

        if(!(attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS))
            break; // can't process without meanful mode
        
        strcpy(e.name, mem);
        e.name_len = strlen(mem);
        e.type = IFTODT(attrs.permissions);
        
        if( !_handler(e) )
            break;
    }

    libssh2_sftp_closedir(sftp_handle);
    
    return 0;
}

int VFSNetSFTPHost::StatFS(const char *_path,
                           VFSStatFS &_stat,
                           const VFSCancelChecker &_cancel_checker)
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return rc;
    
    AutoConnectionReturn acr(conn, this);
    
    LIBSSH2_SFTP_STATVFS statfs;
    rc = libssh2_sftp_statvfs(conn->sftp, _path, strlen(_path), &statfs);
    if(rc < 0)
        return VFSErrorForConnection(*conn);
    
    _stat.total_bytes = statfs.f_blocks * statfs.f_frsize;
    _stat.avail_bytes = statfs.f_bavail * statfs.f_frsize;
    _stat.free_bytes  = statfs.f_ffree  * statfs.f_frsize;
    _stat.volume_name.clear(); // mb some dummy name here?
    
    return 0;
}

int VFSNetSFTPHost::CreateFile(const char* _path, shared_ptr<VFSFile> &_target, const VFSCancelChecker &_cancel_checker)
{
    auto file = make_shared<VFSNetSFTPFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

bool VFSNetSFTPHost::ShouldProduceThumbnails() const
{
    return false;
}

bool VFSNetSFTPHost::IsWritable() const
{
    return true; // dummy now
}

bool VFSNetSFTPHost::IsWritableAtPath(const char *_dir) const
{
    return true; // dummy now
}

int VFSNetSFTPHost::Unlink(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return rc;
    
    AutoConnectionReturn acr(conn, this);
    
    rc = libssh2_sftp_unlink_ex(conn->sftp, _path, (unsigned)strlen(_path));
    
    if(rc < 0)
        return VFSErrorForConnection(*conn);
    
    return 0;
}

int VFSNetSFTPHost::Rename(const char *_old_path, const char *_new_path, const VFSCancelChecker &_cancel_checker)
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return rc;
    
    AutoConnectionReturn acr(conn, this);
    
    rc = libssh2_sftp_rename_ex(conn->sftp, _old_path, (unsigned)strlen(_old_path), _new_path, (unsigned)strlen(_new_path),
                                LIBSSH2_SFTP_RENAME_OVERWRITE | LIBSSH2_SFTP_RENAME_ATOMIC | LIBSSH2_SFTP_RENAME_NATIVE);
    
    if(rc < 0)
        return VFSErrorForConnection(*conn);
    
    return 0;
}

int VFSNetSFTPHost::RemoveDirectory(const char *_path, const VFSCancelChecker &_cancel_checker)
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return rc;
  
    AutoConnectionReturn acr(conn, this);
    
    rc = libssh2_sftp_rmdir_ex(conn->sftp, _path, (unsigned)strlen(_path));
    
    if(rc < 0)
        return VFSErrorForConnection(*conn);
    
    return 0;
}

int VFSNetSFTPHost::CreateDirectory(const char* _path, int _mode, const VFSCancelChecker &_cancel_checker)
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return rc;
    
    AutoConnectionReturn acr(conn, this);
    
    rc = libssh2_sftp_mkdir_ex(conn->sftp, _path, (unsigned)strlen(_path), _mode);
    
    if(rc < 0)
        return VFSErrorForConnection(*conn);
    
    return 0;
}

int VFSNetSFTPHost::VFSErrorForConnection(Connection &_conn) const
{
    using namespace VFSError;
    int sess_errno = libssh2_session_last_errno(_conn.ssh);
    if(sess_errno == 0)
        return 0;
    if(sess_errno == LIBSSH2_ERROR_SFTP_PROTOCOL)
        switch (libssh2_sftp_last_error(_conn.sftp)) {
            case LIBSSH2_FX_OK:                         return 0;
            case LIBSSH2_FX_EOF:                        return NetSFTPEOF;
            case LIBSSH2_FX_NO_SUCH_FILE:               return NetSFTPNoSuchFile;
            case LIBSSH2_FX_PERMISSION_DENIED:          return NetSFTPPermissionDenied;
            case LIBSSH2_FX_FAILURE:                    return NetSFTPFailure;
            case LIBSSH2_FX_BAD_MESSAGE:                return NetSFTPBadMessage;
            case LIBSSH2_FX_NO_CONNECTION:              return NetSFTPNoConnection;
            case LIBSSH2_FX_CONNECTION_LOST:            return NetSFTPConnectionLost;
            case LIBSSH2_FX_OP_UNSUPPORTED:             return NetSFTPOpUnsupported;
            case LIBSSH2_FX_INVALID_HANDLE:             return NetSFTPInvalidHandle;
            case LIBSSH2_FX_NO_SUCH_PATH:               return NetSFTPNoSuchPath;
            case LIBSSH2_FX_FILE_ALREADY_EXISTS:        return NetSFTPFileAlreadyExists;
            case LIBSSH2_FX_WRITE_PROTECT:              return NetSFTPWriteProtect;
            case LIBSSH2_FX_NO_MEDIA:                   return NetSFTPNoMedia;
            case LIBSSH2_FX_NO_SPACE_ON_FILESYSTEM:     return NetSFTPNoSpaceOnFilesystem;
            case LIBSSH2_FX_QUOTA_EXCEEDED:             return NetSFTPQuotaExceeded;
            case LIBSSH2_FX_UNKNOWN_PRINCIPAL:          return NetSFTPUnknownPrincipal;
            case LIBSSH2_FX_LOCK_CONFLICT:              return NetSFTPLockConflict;
            case LIBSSH2_FX_DIR_NOT_EMPTY:              return NetSFTPDirNotEmpty;
            case LIBSSH2_FX_NOT_A_DIRECTORY:            return NetSFTPNotADir;
            case LIBSSH2_FX_INVALID_FILENAME:           return NetSFTPInvalidFilename;
            case LIBSSH2_FX_LINK_LOOP:                  return NetSFTPLinkLoop;
            default:                                    return NetSFTPFailure;
        }
    switch (sess_errno) {
        case LIBSSH2_ERROR_BANNER_RECV:
        case LIBSSH2_ERROR_BANNER_SEND:
        case LIBSSH2_ERROR_INVALID_MAC:
        case LIBSSH2_ERROR_KEX_FAILURE:
        case LIBSSH2_ERROR_ALLOC:
        case LIBSSH2_ERROR_SOCKET_SEND:
        case LIBSSH2_ERROR_KEY_EXCHANGE_FAILURE:
        case LIBSSH2_ERROR_TIMEOUT:
        case LIBSSH2_ERROR_HOSTKEY_INIT:
        case LIBSSH2_ERROR_HOSTKEY_SIGN:
        case LIBSSH2_ERROR_DECRYPT:
        case LIBSSH2_ERROR_SOCKET_DISCONNECT:
        case LIBSSH2_ERROR_PROTO:
        case LIBSSH2_ERROR_PASSWORD_EXPIRED:
        case LIBSSH2_ERROR_FILE:
        case LIBSSH2_ERROR_METHOD_NONE:
        case LIBSSH2_ERROR_AUTHENTICATION_FAILED:
        case LIBSSH2_ERROR_PUBLICKEY_UNVERIFIED:
        case LIBSSH2_ERROR_CHANNEL_OUTOFORDER:
        case LIBSSH2_ERROR_CHANNEL_FAILURE:
        case LIBSSH2_ERROR_CHANNEL_REQUEST_DENIED:
        case LIBSSH2_ERROR_CHANNEL_UNKNOWN:
        case LIBSSH2_ERROR_CHANNEL_WINDOW_EXCEEDED:
        case LIBSSH2_ERROR_CHANNEL_PACKET_EXCEEDED:
        case LIBSSH2_ERROR_CHANNEL_CLOSED:
        case LIBSSH2_ERROR_CHANNEL_EOF_SENT:
        case LIBSSH2_ERROR_ZLIB:
        case LIBSSH2_ERROR_SOCKET_TIMEOUT:
        case LIBSSH2_ERROR_SFTP_PROTOCOL:
        case LIBSSH2_ERROR_REQUEST_DENIED:
        case LIBSSH2_ERROR_METHOD_NOT_SUPPORTED:
        case LIBSSH2_ERROR_INVAL:
        case LIBSSH2_ERROR_INVALID_POLL_TYPE:
        case LIBSSH2_ERROR_PUBLICKEY_PROTOCOL:
        case LIBSSH2_ERROR_EAGAIN:
        case LIBSSH2_ERROR_BUFFER_TOO_SMALL:
        case LIBSSH2_ERROR_BAD_USE:
        case LIBSSH2_ERROR_COMPRESS:
        case LIBSSH2_ERROR_OUT_OF_BOUNDARY:
        case LIBSSH2_ERROR_AGENT_PROTOCOL:
        case LIBSSH2_ERROR_SOCKET_RECV:
        case LIBSSH2_ERROR_ENCRYPT:
        case LIBSSH2_ERROR_BAD_SOCKET:
        case LIBSSH2_ERROR_KNOWN_HOSTS: return NetSFTPErrorSSH; // until the better times we dont have a better errors explanation
        default:                        return NetSFTPErrorSSH;
    }
    return NetSFTPErrorSSH;
}

const string& VFSNetSFTPHost::ServerUrl() const noexcept
{
    return Config().server_url;
}

const string& VFSNetSFTPHost::User() const noexcept
{
    return Config().user;
}

const string& VFSNetSFTPHost::Keypath() const noexcept
{
    return Config().keypath;
}

long VFSNetSFTPHost::Port() const noexcept
{
    return Config().port;
}
