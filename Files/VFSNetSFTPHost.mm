//
//  VFSNetSFTPHost.mm
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "VFSNetSFTPHost.h"
#include "VFSListing.h"

using namespace VFSNetSFTP;

bool VFSNetSFTPOptions::Equal(const VFSHostOptions &_r) const
{
    if(typeid(_r) != typeid(*this))
        return false;
    
    const VFSNetSFTPOptions& r = (const VFSNetSFTPOptions&)_r;
    return user == r.user &&
    passwd == r.passwd &&
    port == r.port;
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
    m_Options = make_shared<VFSNetSFTPOptions>(_options);
    unique_ptr<VFSNetSFTP::Connection> conn;
    int rc = GetConnection(conn);
    if(rc != 0)
        return rc;
    
    ReturnConnection(move(conn));
    
    return 0;
}

int VFSNetSFTPHost::SpawnConnection(unique_ptr<VFSNetSFTP::Connection> &_t)
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
    
    if (libssh2_userauth_password(connection->ssh, m_Options->user.c_str(), m_Options->passwd.c_str())) {
//        fprintf(stderr, "Authentication by password failed.\n");
        return -1;
    }
    
    connection->sftp = libssh2_sftp_init(connection->ssh);
    
    if (!connection->sftp) {
//        fprintf(stderr, "Unable to init SFTP session\n");
        return -1;
    }
    
    libssh2_session_set_blocking(connection->ssh, 1);
    

    _t = move(connection);
    return 0;
}

int VFSNetSFTPHost::GetConnection(unique_ptr<VFSNetSFTP::Connection> &_t)
{
    lock_guard<mutex> lock(m_ConnectionsLock);
    
    for(auto i = m_Connections.begin(); i != m_Connections.end(); ++i)
        if((*i)->Alive()) {
            _t = move(*i);
            m_Connections.erase(i);
            return 0;
        }
    
    return SpawnConnection(_t);
}

void VFSNetSFTPHost::ReturnConnection(unique_ptr<VFSNetSFTP::Connection> _t)
{
    if(!_t->Alive())
        return;
    
    lock_guard<mutex> lock(m_ConnectionsLock);

    m_Connections.emplace_back(move(_t));
}

unsigned VFSNetSFTPHost::InetAddr() const
{
    return inet_addr(JunctionPath());
}

int VFSNetSFTPHost::FetchDirectoryListing(const char *_path,
                                          shared_ptr<VFSListing> *_target,
                                          int _flags,
                                          bool (^_cancel_checker)())
{
    unique_ptr<VFSNetSFTP::Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return -1;
    
    LIBSSH2_SFTP_HANDLE *sftp_handle = libssh2_sftp_opendir(conn->sftp, _path);
    if (!sftp_handle) {
        return -1;
    }
 
    auto dir = make_shared<VFSGenericListing>(_path, shared_from_this());
 
    do {
        char mem[512];
        char longentry[512];
        LIBSSH2_SFTP_ATTRIBUTES attrs;
        
        /* loop until we fail */
        rc = libssh2_sftp_readdir_ex(sftp_handle, mem, sizeof(mem), longentry, sizeof(longentry), &attrs);
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
        
        
//    unsigned long permissions;
        
        
        it.FindExtension();
        
        
            /* rc is the length of the file name in the mem
             buffer */
            
/*            if (longentry[0] != '\0') {
                printf("%s\n", longentry);
            } else {
                if(attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) {
                    // this should check what permissions it is and print the output accordingly
                    printf("--fix----- ");
                }
                else {
                    printf("---------- ");
                }
                
                if(attrs.flags & LIBSSH2_SFTP_ATTR_UIDGID) {
                    printf("%4ld %4ld ", attrs.uid, attrs.gid);
                }
                else {
                    printf("   -    - ");
                }
                
                if(attrs.flags & LIBSSH2_SFTP_ATTR_SIZE) {
                    printf("%8" PRIu64 " ", attrs.filesize);
                }
                
                printf("%s\n", mem);
            }*/
        
    } while (true);
    
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
    unique_ptr<VFSNetSFTP::Connection> conn;
    int rc = GetConnection(conn);
    if(rc)
        return -1;

    LIBSSH2_SFTP_ATTRIBUTES attrs;
    rc = libssh2_sftp_stat_ex(conn->sftp,
                              _path,
                              (unsigned)strlen(_path),
                              LIBSSH2_SFTP_STAT,
                              &attrs);
    if(rc)
        return -1;
    
    // check flags
    
    _st.mode = attrs.permissions;
    _st.uid = (uid_t)attrs.uid;
    _st.gid = (gid_t)attrs.gid;
    _st.atime.tv_sec = attrs.atime;
    _st.mtime.tv_sec = attrs.mtime;
    _st.ctime.tv_sec = attrs.mtime;
    _st.btime.tv_sec = attrs.mtime;
    _st.size = attrs.filesize;
    
    // set meaning
    
    ReturnConnection(move(conn));
    
    return 0;
}



/*
LIBSSH2_API int libssh2_sftp_stat_ex(LIBSSH2_SFTP *sftp,
                                     const char *path,
                                     unsigned int path_len,
                                     int stat_type,
                                     LIBSSH2_SFTP_ATTRIBUTES *attrs);
#define libssh2_sftp_stat(sftp, path, attrs) \
libssh2_sftp_stat_ex((sftp), (path), strlen(path), LIBSSH2_SFTP_STAT, \
(attrs))
#define libssh2_sftp_lstat(sftp, path, attrs) \
libssh2_sftp_stat_ex((sftp), (path), strlen(path), LIBSSH2_SFTP_LSTAT, \
(attrs))
#define libssh2_sftp_setstat(sftp, path, attrs) \
libssh2_sftp_stat_ex((sftp), (path), strlen(path), LIBSSH2_SFTP_SETSTAT, \
(attrs))*/