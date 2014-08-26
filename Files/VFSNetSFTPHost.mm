//
//  VFSNetSFTPHost.mm
//  Files
//
//  Created by Michael G. Kazakov on 25/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "VFSNetSFTPHost.h"
#include "VFSNetSFTPInternals.h"
#include "VFSListing.h"

/* last resort for systems not defining PRIu64 in inttypes.h */
#ifndef __PRI64_PREFIX
#ifdef WIN32
#define __PRI64_PREFIX "I64"
#else
#if __WORDSIZE == 64
#define __PRI64_PREFIX "l"
#else
#define __PRI64_PREFIX "ll"
#endif /* __WORDSIZE */
#endif /* WIN32 */
#endif /* !__PRI64_PREFIX */
#ifndef PRIu64
#define PRIu64 __PRI64_PREFIX "u"
#endif  /* PRIu64 */

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

int VFSNetSFTPHost::Open(const char *_starting_dir,
                         const VFSNetSFTPOptions &_options)
{
    m_Options = make_shared<VFSNetSFTPOptions>(_options);
    unique_ptr<VFSNetSFTP::Connection> conn;
    int rc = SpawnConnection(conn);
    
    int a = 10;
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
    int rc = SpawnConnection(conn);
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
        
        dir->m_Items.emplace_back();
        auto &it = dir->m_Items.back();
        
        it.m_Name = strdup(mem);
        it.m_NameLen = strlen(mem);
        it.m_CFName = CFStringCreateWithCString(0, mem, kCFStringEncodingUTF8);
        it.m_NeedReleaseName = true;
        it.m_NeedReleaseCFName = true;

/*
#define LIBSSH2_SFTP_ATTR_SIZE              0x00000001
#define LIBSSH2_SFTP_ATTR_UIDGID            0x00000002
#define LIBSSH2_SFTP_ATTR_PERMISSIONS       0x00000004
#define LIBSSH2_SFTP_ATTR_ACMODTIME         0x00000008
#define LIBSSH2_SFTP_ATTR_EXTENDED          0x80000000
  */
    
        if(attrs.flags & LIBSSH2_SFTP_ATTR_SIZE)
            it.m_Size = attrs.filesize;
        if(attrs.flags & LIBSSH2_SFTP_ATTR_UIDGID) {
            it.m_UID = (uid_t)attrs.uid;
            it.m_GID = (uid_t)attrs.gid;
        }
//    unsigned long atime,
        if(attrs.flags & LIBSSH2_SFTP_ATTR_ACMODTIME) {
            it.m_ATime = attrs.atime;
            it.m_MTime = attrs.mtime;
            it.m_CTime = attrs.mtime;
            it.m_BTime = attrs.mtime;
        }
        
        /*
         * Reproduce the POSIX file modes here for systems that are not POSIX
         * compliant.
         *
         * These is used in "permissions" of "struct _LIBSSH2_SFTP_ATTRIBUTES"
         */
        /* File type */
//#define	S_IFMT		0170000		/* [XSI] type of file mask */
//#define	S_IFIFO		0010000		/* [XSI] named pipe (fifo) */
//#define	S_IFCHR		0020000		/* [XSI] character special */
//#define	S_IFDIR		0040000		/* [XSI] directory */
//#define	S_IFBLK		0060000		/* [XSI] block special */
//#define	S_IFREG		0100000		/* [XSI] regular */
//#define	S_IFLNK		0120000		/* [XSI] symbolic link */
//#define	S_IFSOCK	0140000		/* [XSI] socket */
        
//#define LIBSSH2_SFTP_S_IFMT         0170000     /* type of file mask */
//#define LIBSSH2_SFTP_S_IFIFO        0010000     /* named pipe (fifo) */
//#define LIBSSH2_SFTP_S_IFCHR        0020000     /* character special */
//#define LIBSSH2_SFTP_S_IFDIR        0040000     /* directory */
//#define LIBSSH2_SFTP_S_IFBLK        0060000     /* block special */
//#define LIBSSH2_SFTP_S_IFREG        0100000     /* regular */
//#define LIBSSH2_SFTP_S_IFLNK        0120000     /* symbolic link */
//#define LIBSSH2_SFTP_S_IFSOCK       0140000     /* socket */
//        
//        /* File mode */
//        /* Read, write, execute/search by owner */
//#define LIBSSH2_SFTP_S_IRWXU        0000700     /* RWX mask for owner */
//#define LIBSSH2_SFTP_S_IRUSR        0000400     /* R for owner */
//#define LIBSSH2_SFTP_S_IWUSR        0000200     /* W for owner */
//#define LIBSSH2_SFTP_S_IXUSR        0000100     /* X for owner */
//        /* Read, write, execute/search by group */
//#define LIBSSH2_SFTP_S_IRWXG        0000070     /* RWX mask for group */
//#define LIBSSH2_SFTP_S_IRGRP        0000040     /* R for group */
//#define LIBSSH2_SFTP_S_IWGRP        0000020     /* W for group */
//#define LIBSSH2_SFTP_S_IXGRP        0000010     /* X for group */
//        /* Read, write, execute/search by others */
//#define LIBSSH2_SFTP_S_IRWXO        0000007     /* RWX mask for other */
//#define LIBSSH2_SFTP_S_IROTH        0000004     /* R for other */
//#define LIBSSH2_SFTP_S_IWOTH        0000002     /* W for other */
//#define LIBSSH2_SFTP_S_IXOTH        0000001     /* X for other */
//        
//        virtual bool            IsDir()     const override { return (m_Mode & S_IFMT) == S_IFDIR;   }
//        virtual bool            IsReg()     const override { return (m_Mode & S_IFMT) == S_IFREG;   }
//        virtual bool            IsSymlink() const override { return m_Type == DT_LNK;               }
        
        if(attrs.flags & LIBSSH2_SFTP_ATTR_PERMISSIONS) {
            it.m_Mode = attrs.permissions;
            it.m_Type = IFTODT(attrs.permissions);
//            DT_LNK
            
//            #define	IFTODT(mode)	(((mode) & 0170000) >> 12)
        }
        
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
    
    return 0;
}

int VFSNetSFTPHost::Stat(const char *_path,
                         VFSStat &_st,
                         int _flags,
                         bool (^_cancel_checker)())
{
    unique_ptr<VFSNetSFTP::Connection> conn;
    int rc = SpawnConnection(conn);
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