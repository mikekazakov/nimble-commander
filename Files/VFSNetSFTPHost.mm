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
    return user == r.user &&
        passwd == r.passwd &&
        port == r.port;
}

VFSNetSFTPHost::Connection::~Connection()
{
    if(sftp) {
        libssh2_sftp_shutdown(sftp);
        sftp = nullptr;
    }
    
    if(ssh) {
        libssh2_session_disconnect(ssh, "bye");
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
        return -1; // need something meaningful
    if(remote_host->h_addrtype != AF_INET)
        return -1; // need something meaningful
    m_HostAddr = *(in_addr_t *) remote_host->h_addr_list[0];
    
    m_Options = make_shared<VFSNetSFTPOptions>(_options);
    
    unique_ptr<Connection> conn;
    int rc = SpawnSSH2(conn);
    if(rc != 0)
        return rc;
    
    LIBSSH2_CHANNEL *channel = libssh2_channel_open_session(conn->ssh);
    if(channel == nullptr)
        return -1;
    
    rc = libssh2_channel_exec(channel, "pwd");
    if(rc < 0)
        return -1;
    
    char buffer[MAXPATHLEN];
    rc = (int)libssh2_channel_read( channel, buffer, sizeof(buffer) );
    if( rc <= 0 )
        return -1;
    buffer[rc - 1] = 0;
    
    m_HomeDir = buffer;
    
    libssh2_channel_close(channel);
    libssh2_channel_free(channel);
    
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
    sin.sin_port = htons(m_Options->port >= 0 ? m_Options->port : 22);
    sin.sin_addr.s_addr = hostaddr;
    if (connect(connection->socket, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in)) != 0) {
        fprintf(stderr, "failed to connect remote sftp host!\n");
        return -1;
    }
    
    int optval = 1;
    setsockopt(connection->socket, SOL_SOCKET, SO_KEEPALIVE, &optval, sizeof(optval));

    
    connection->ssh = libssh2_session_init();
    if(!connection->ssh)
        return -1;
    
    rc = libssh2_session_handshake(connection->ssh, connection->socket);
    if(rc) {
//        fprintf(stderr, "Failure establishing SSH session: %d\n", rc);
        return -1;
    }
    
//    libssh2_userauth_password_ex((session), (username), strlen(username), \
//                                 (password), strlen(password), NULL)
    
    
    if (libssh2_userauth_password_ex(connection->ssh,
                                     m_Options->user.c_str(),
                                     (unsigned)m_Options->user.length(),
                                     m_Options->passwd.c_str(),
                                     (unsigned)m_Options->passwd.length(),
                                     NULL)) {
//        fprintf(stderr, "Authentication by password failed.\n");
        return -1;
    }

    libssh2_session_set_blocking(connection->ssh, 1);
    
    _t = move(connection);
    
    return 0;
}

int VFSNetSFTPHost::SpawnSFTP(unique_ptr<Connection> &_t)
{    
    _t->sftp = libssh2_sftp_init(_t->ssh);
    
    if (!_t->sftp) {
        //        fprintf(stderr, "Unable to init SFTP session\n");
        return -1;
    }

    return 0;
}

int VFSNetSFTPHost::GetConnection(unique_ptr<Connection> &_t)
{
    lock_guard<mutex> lock(m_ConnectionsLock);
    
    for(auto i = m_Connections.begin(); i != m_Connections.end(); ++i)
        if((*i)->Alive()) {
            _t = move(*i);
            m_Connections.erase(i);
            return 0;
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
        return -1;
    
    LIBSSH2_SFTP_HANDLE *sftp_handle = libssh2_sftp_open_ex(conn->sftp, _path, (unsigned)strlen(_path), 0, 0, LIBSSH2_SFTP_OPENDIR);
    if (!sftp_handle) {
        return -1;
    }
 
    auto dir = make_shared<VFSGenericListing>(_path, shared_from_this());
 
    while (true) {
        char mem[MAXPATHLEN];
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        
        /* loop until we fail */
        rc = libssh2_sftp_readdir_ex(sftp_handle, mem, sizeof(mem), nullptr, 0, &attrs);        
        if(rc <= 0)
            break;
        
        if( mem[0] == '.' && mem[1] == 0 ) continue; // do not process self entry
        if( mem[0] == '.' && mem[1] == '.' && mem[2] == 0 ) // special case for dot-dot directory
        {
            if(_flags & VFSHost::F_NoDotDot) continue;
            
            if(strcmp(_path, "/") == 0)
                continue; // skip .. for root directory
        }
        
        dir->m_Items.emplace_back();
        auto &it = dir->m_Items.back();
        
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

    *_target = dir;
    
    ReturnConnection(move(conn));
    
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
        return -1;

    LIBSSH2_SFTP_ATTRIBUTES attrs;
    rc = libssh2_sftp_stat_ex(conn->sftp,
                              _path,
                              (unsigned)strlen(_path),
                              (_flags & F_NoFollow) ? LIBSSH2_SFTP_LSTAT : LIBSSH2_SFTP_STAT,
                              &attrs);
    if(rc)
        return -1;

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
        
    ReturnConnection(move(conn));
    
    return 0;
}

int VFSNetSFTPHost::IterateDirectoryListing(const char *_path,
                                            bool (^_handler)(const VFSDirEnt &_dirent))
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return -1;
    
    LIBSSH2_SFTP_HANDLE *sftp_handle = libssh2_sftp_open_ex(conn->sftp, _path, (unsigned)strlen(_path), 0, 0, LIBSSH2_SFTP_OPENDIR);
    if (!sftp_handle) {
        return -1;
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
    
    ReturnConnection(move(conn));
    
    return 0;
}

int VFSNetSFTPHost::StatFS(const char *_path,
                           VFSStatFS &_stat,
                           bool (^_cancel_checker)())
{
    unique_ptr<Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return -1;
    
    LIBSSH2_SFTP_STATVFS statfs;
    rc = libssh2_sftp_statvfs(conn->sftp, _path, strlen(_path), &statfs);
    if(rc < 0)
        return -1;
    
    _stat.total_bytes = statfs.f_blocks * statfs.f_bsize;
    _stat.avail_bytes = statfs.f_bavail * statfs.f_bsize;
    _stat.free_bytes  = statfs.f_ffree  * statfs.f_bsize;
    _stat.volume_name.clear(); // mb some dummy name here?
    
    ReturnConnection(move(conn));
    
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
