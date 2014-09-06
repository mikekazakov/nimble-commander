//
//  VFSNetSFTPHost.mm
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "3rd_party/built/include/libssh2.h"
#import "3rd_party/built/include/libssh2_sftp.h"
#import "VFSNetSFTPHost.h"
#import "VFSListing.h"
#import "VFSNetSFTPFile.h"


bool VFSNetSFTPOptions::Equal(const VFSHostOptions &_r) const
{
    if(typeid(_r) != typeid(*this))
        return false;
    
    const VFSNetSFTPOptions& r = (const VFSNetSFTPOptions&)_r;
    return user == r.user && passwd == r.passwd && port == r.port;
}

VFSNetSFTPHost::Connection::~Connection()
{
    if(sftp) {
        libssh2_sftp_shutdown(sftp);
        sftp = nullptr;
    }
    
    if(ssh) {
        libssh2_session_disconnect(ssh, "Farewell from Files!");
        libssh2_session_free(ssh);
        ssh = nullptr;
    }
    
    if(socket >= 0) {
        close(socket);
        socket = -1;
    }
}

bool VFSNetSFTPHost::Connection::Alive() const {
    int error = 0;
    socklen_t len = sizeof (error);
    int retval = getsockopt (socket, SOL_SOCKET, SO_ERROR, &error, &len );
    return retval == 0;
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

const char *VFSNetSFTPHost::FSTag() const
{
    return Tag;
}

VFSNetSFTPHost::VFSNetSFTPHost(const char *_serv_url):
    VFSHost(_serv_url, nullptr)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int rc = libssh2_init(0);
        assert(rc == 0);
    });
}

int VFSNetSFTPHost::Open(const VFSNetSFTPOptions &_options)
{
    struct hostent *remote_host = gethostbyname(JunctionPath());
    if(!remote_host)
        return VFSError::NetSFTPCouldntResolveHost; // need something meaningful
    if(remote_host->h_addrtype != AF_INET)
        return VFSError::NetSFTPCouldntResolveHost; // need something meaningful
    m_HostAddr = *(in_addr_t *) remote_host->h_addr_list[0];
    
    m_Options = make_shared<VFSNetSFTPOptions>(_options);
    
    unique_ptr<Connection> conn;
    int rc = SpawnSSH2(conn);
    if(rc != 0)
        return rc;
    
    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(conn->ssh);
    if(channel == nullptr)
        return VFSError::NetSFTPErrorSSH;
    
    rc = libssh2_channel_exec(channel, "pwd");
    if(rc < 0) {
        libssh2_channel_close(channel);
        libssh2_channel_free(channel);
        return VFSError::NetSFTPErrorSSH;
    }
    
    char buffer[MAXPATHLEN];
    rc = (int)libssh2_channel_read( channel, buffer, sizeof(buffer) );
    libssh2_channel_close(channel);
    libssh2_channel_free(channel);
    
    if( rc <= 0 )
        return VFSError::NetSFTPErrorSSH;
    buffer[rc - 1] = 0;
    
    m_HomeDir = buffer;
    
    rc = SpawnSFTP(conn);
    if(rc < 0)
        return rc;
    
    ReturnConnection(move(conn));
    
    return 0;
}

const string& VFSNetSFTPHost::HomeDir() const
{
    return m_HomeDir;
}

int VFSNetSFTPHost::SpawnSSH2(unique_ptr<Connection> &_t)
{
    assert(m_Options);
    _t = nullptr;
    auto connection = make_unique<Connection>();

    int rc;
    
    in_addr_t hostaddr = InetAddr();
    connection->socket = socket(AF_INET, SOCK_STREAM, 0);
    sockaddr_in sin;
    sin.sin_family = AF_INET;
    sin.sin_port = htons(m_Options->port > 0 ? m_Options->port : 22);
    sin.sin_addr.s_addr = hostaddr;
    if (connect(connection->socket, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in)) != 0)
        return VFSError::NetSFTPCouldntConnect;
    
    int optval = 1;
    setsockopt(connection->socket, SOL_SOCKET, SO_KEEPALIVE, &optval, sizeof(optval));

    
    connection->ssh = libssh2_session_init();
    if(!connection->ssh)
        return VFSError::GenericError;
    
    rc = libssh2_session_handshake(connection->ssh, connection->socket);
    if(rc)
        return VFSError::NetSFTPCouldntEstablishSSH;
    
    if (libssh2_userauth_password_ex(connection->ssh,
                                     m_Options->user.c_str(),
                                     (unsigned)m_Options->user.length(),
                                     m_Options->passwd.c_str(),
                                     (unsigned)m_Options->passwd.length(),
                                     NULL))
        return VFSError::NetSFTPCouldntAuthenticate;

    libssh2_session_set_blocking(connection->ssh, 1);
    
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
    {
        lock_guard<mutex> lock(m_ConnectionsLock);
        for(auto i = m_Connections.begin(); i != m_Connections.end(); ++i)
            if((*i)->Alive()) {
                _t = move(*i);
                m_Connections.erase(i);
                return 0;
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
                                          shared_ptr<VFSListing> *_target,
                                          int _flags,
                                          bool (^_cancel_checker)())
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
 
    auto dir = make_shared<VFSGenericListing>(_path, shared_from_this());
    bool need_dot_dot = !(_flags & VFSHost::F_NoDotDot) && strcmp(_path, "/") != 0;
    
    if(need_dot_dot)
        dir->m_Items.emplace_back(); // reserve a space for dot-dot entry
    
    while (true) {
        char mem[MAXPATHLEN];
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        if(libssh2_sftp_readdir_ex(sftp_handle, mem, sizeof(mem), nullptr, 0, &attrs) <= 0)
            break;
        
        bool isdotdot = false;
        if( mem[0] == '.' && mem[1] == 0 )
            continue; // do not process self entry
        else if( mem[0] == '.' && mem[1] == '.' && mem[2] == 0 ) // special case for dot-dot directory
        {
            if(_flags & VFSHost::F_NoDotDot) continue;
            
            if(strcmp(_path, "/") == 0)
                continue; // skip .. for root directory
            
            isdotdot = true;
        }
        else { // all other cases
            dir->m_Items.emplace_back();
        }

        auto &it = isdotdot ? dir->m_Items[0] : dir->m_Items.back();
        
        it.m_Name = strdup(mem);
        it.m_NameLen = strlen(mem);
        it.m_CFName = CFStringCreateWithCString(0, mem, kCFStringEncodingUTF8);
        it.m_NeedReleaseName = true;
        it.m_NeedReleaseCFName = true;

        if(attrs.flags & LIBSSH2_SFTP_ATTR_SIZE)
            it.m_Size = attrs.filesize;
        if(attrs.flags & LIBSSH2_SFTP_ATTR_UIDGID) {
            it.m_UID = (uid_t)attrs.uid;
            it.m_GID = (uid_t)attrs.gid;
        }
        if(attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) {
            it.m_ATime = attrs.atime;
            it.m_MTime = attrs.mtime;
            it.m_CTime = attrs.mtime;
            it.m_BTime = attrs.mtime;
        }
        if(attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) {
            it.m_Mode = attrs.permissions;
            it.m_Type = IFTODT(attrs.permissions);
        }
        
        if(it.IsDir())
            it.m_Size = VFSListingItem::InvalidSize;
        
        it.FindExtension();
    }
    
    libssh2_sftp_closedir(sftp_handle);

    // check for a symlinks and read additional info
    for(auto &i: *dir ){
        if(i.IsSymlink()) {
            char path[MAXPATHLEN], symlink[MAXPATHLEN];
            strcpy(path, _path);
            if( path[strlen(path)-1] != '/' ) strcat(path, "/");
            strcat(path, i.Name());
            
            // read where symlink points at
            rc = libssh2_sftp_symlink_ex(conn->sftp, path, (unsigned)strlen(path), symlink, MAXPATHLEN, LIBSSH2_SFTP_READLINK);
            if(rc >= 0) {
                ((VFSGenericListingItem*)&i)->m_Symlink = strdup(symlink);
                ((VFSGenericListingItem*)&i)->m_NeedReleaseSymlink = strdup(symlink);
            }
            else {
                ((VFSGenericListingItem*)&i)->m_Symlink = ""; // fallback case to return something on request
            }

            // read info about real object
            LIBSSH2_SFTP_ATTRIBUTES stat;
            if(libssh2_sftp_stat_ex(conn->sftp, path, (unsigned)strlen(path), LIBSSH2_SFTP_STAT, &stat) >= 0) {
                ((VFSGenericListingItem*)&i)->m_Mode = stat.permissions;
                if(!i.IsDir())
                    ((VFSGenericListingItem*)&i)->m_Size = stat.filesize;
                else
                    ((VFSGenericListingItem*)&i)->m_Size = VFSListingItem::InvalidSize;
            }
        }
    }
    
    *_target = dir;
    
    return 0;
}

int VFSNetSFTPHost::Stat(const char *_path,
                         VFSStat &_st,
                         int _flags,
                         bool (^_cancel_checker)())
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
                              (_flags & F_NoFollow) ? LIBSSH2_SFTP_LSTAT : LIBSSH2_SFTP_STAT,
                              &attrs);
    if(rc)
        return VFSErrorForConnection(*conn);

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
                                            bool (^_handler)(const VFSDirEnt &_dirent))
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
                           bool (^_cancel_checker)())
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
    
    _stat.total_bytes = statfs.f_blocks * statfs.f_bsize;
    _stat.avail_bytes = statfs.f_bavail * statfs.f_bsize;
    _stat.free_bytes  = statfs.f_ffree  * statfs.f_bsize;
    _stat.volume_name.clear(); // mb some dummy name here?
    
    return 0;
}

int VFSNetSFTPHost::CreateFile(const char* _path, shared_ptr<VFSFile> &_target, bool (^_cancel_checker)())
{
    auto file = make_shared<VFSNetSFTPFile>(_path, SharedPtr());
    if(_cancel_checker && _cancel_checker())
        return VFSError::Cancelled;
    _target = file;
    return VFSError::Ok;
}

string VFSNetSFTPHost::VerboseJunctionPath() const
{
    return string("sftp://") + JunctionPath();
}

shared_ptr<VFSHostOptions> VFSNetSFTPHost::Options() const
{
    return m_Options;
}

bool VFSNetSFTPHost::ShouldProduceThumbnails() const
{
    return false;
}

bool VFSNetSFTPHost::IsWriteable() const
{
    return true; // dummy now
}

bool VFSNetSFTPHost::IsWriteableAtPath(const char *_dir) const
{
    return true; // dummy now
}

int VFSNetSFTPHost::Unlink(const char *_path, bool (^_cancel_checker)())
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

int VFSNetSFTPHost::Rename(const char *_old_path, const char *_new_path, bool (^_cancel_checker)())
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

int VFSNetSFTPHost::RemoveDirectory(const char *_path, bool (^_cancel_checker)())
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

int VFSNetSFTPHost::CreateDirectory(const char* _path, int _mode, bool (^_cancel_checker)() )
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
