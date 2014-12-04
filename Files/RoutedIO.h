//
//  RoutedIO.h
//  Files
//
//  Created by Michael G. Kazakov on 29/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <xpc/xpc.h>


/**
 * NB!
 * readdir call uses _readdir_unlocked (without mutex guarding) and requires that call should be performed without possible race conditions.
 */
class PosixIOInterface
{
public:
    virtual bool            isrouted() const = 0;
    virtual int             open(const char *_path, int _flags, int _mode = 0) = 0;
    virtual int             close(int _fd) = 0;
    virtual ssize_t         read(int _fd, void *_buf, size_t _nbyte) = 0;
    virtual ssize_t         write(int _fd, const void *_buf, size_t _nbyte) = 0;
    virtual off_t           lseek(int _fd, off_t _offset, int _whence) = 0;
    virtual DIR            *opendir(const char *_path) = 0;
    virtual struct dirent  *readdir(DIR *_dir) = 0;
    virtual int             closedir(DIR *_dir) = 0;
    virtual int             stat(const char *_path, struct stat *_st) = 0;
    virtual int             lstat(const char *_path, struct stat *_st) = 0;
    virtual int             mkdir(const char *_path, mode_t _mode) = 0;
    virtual int             rmdir(const char *_path) = 0;
    virtual int             unlink(const char *_path) = 0;
    virtual int             rename(const char *_old, const char *_new) = 0;
    virtual int             chown(const char *_path, uid_t _uid, gid_t _gid) = 0;
    virtual int             chflags(const char *_path, u_int _flags) = 0;
    virtual ssize_t         readlink(const char *_path, char *_symlink, size_t _buf_sz) = 0;
    virtual int             symlink(const char *_value, const char *_symlink_path) = 0;
    virtual int             link(const char *_path_exist, const char *_path_newnode) = 0;
};

class RoutedIO
{
public:
    static PosixIOInterface &Direct;
    static PosixIOInterface &Default;
    static PosixIOInterface &InterfaceForAccess(const char *_path, int _mode) noexcept;
    
    RoutedIO();
    static RoutedIO& Instance();
    
    bool Enabled() const noexcept;
    bool TurnOn();
    void TurnOff();
    
    xpc_connection_t Connection();
    bool IsHelperAlive(); // blocking I/O
    
private:
    RoutedIO(RoutedIO&) = delete;
    void operator=(RoutedIO&) = delete;
    bool Connect();
    bool AskToInstallHelper();
    bool IsHelperInstalled();
    bool IsHelperCurrent();    
    bool ConnectionAvailable();
    bool AuthenticateAsAdmin();
    bool SayImAuthenticated(xpc_connection_t _connection);
    
    volatile bool    m_Enabled    = false;
    volatile bool    m_AuthenticatedAsAdmin = false;
    xpc_connection_t m_Connection = nullptr;
};

inline bool RoutedIO::Enabled() const noexcept
{
    return m_Enabled;
}

inline PosixIOInterface &RoutedIO::InterfaceForAccess(const char *_path, int _mode) noexcept
{
    if(configuration::version != configuration::Version::Full)
        return Direct;
    
    if(!Instance().Enabled())
        return Direct;
    
    return access(_path, _mode) == 0 ? RoutedIO::Direct : RoutedIO::Default;
}
