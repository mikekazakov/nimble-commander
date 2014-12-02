//
//  RoutedIOInterfaces.cpp
//  Files
//
//  Created by Michael G. Kazakov on 29/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "RoutedIOInterfaces.h"

static const uid_t g_UID = getuid();
static const gid_t g_GID = getgid();

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

// trivial wrappers
int PosixIOInterfaceNative::open(const char *_path, int _flags, int _mode) { return ::open(_path, _flags, _mode); }
int	PosixIOInterfaceNative::close(int _fd) { return ::close(_fd); }
ssize_t PosixIOInterfaceNative::read(int _fildes, void *_buf, size_t _nbyte) { return ::read(_fildes, _buf, _nbyte); }
ssize_t PosixIOInterfaceNative::write(int _fildes, const void *_buf, size_t _nbyte) { return ::write(_fildes, _buf, _nbyte); }
DIR *PosixIOInterfaceNative::opendir(const char *_path) { return ::opendir(_path); }
int PosixIOInterfaceNative::closedir(DIR *_dir) { return ::closedir(_dir); }
struct dirent *PosixIOInterfaceNative::readdir(DIR *_dir) { return ::_readdir_unlocked(_dir, 1); }
int PosixIOInterfaceNative::stat(const char *_path, struct stat *_st) { return ::stat(_path, _st); }
int PosixIOInterfaceNative::lstat(const char *_path, struct stat *_st) { return ::lstat(_path, _st); }
int	PosixIOInterfaceNative::mkdir(const char *_path, mode_t _mode) { return ::mkdir(_path, _mode); }
int	PosixIOInterfaceNative::chown(const char *_path, uid_t _uid, gid_t _gid) { return ::chown(_path, _uid, _gid); }
int PosixIOInterfaceNative::rmdir(const char *_path) { return ::rmdir(_path); }
int PosixIOInterfaceNative::unlink(const char *_path) { return ::unlink(_path); }

PosixIOInterfaceRouted::PosixIOInterfaceRouted(RoutedIO &_inst):
    inst(_inst)
{
}

inline xpc_connection_t PosixIOInterfaceRouted::Connection()
{
    if(!inst.Enabled())
        return nullptr;
    return inst.Connection();
}

int PosixIOInterfaceRouted::open(const char *_path, int _flags, int _mode)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::open(_path, _flags, _mode);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "open");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "flags", _flags);
    xpc_dictionary_set_int64 (message, "mode", _mode);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::open(_path, _flags, _mode);
    }
    
    if( int err = (int)xpc_dictionary_get_int64(reply, "error") ) {
        // got a graceful error, propaganate it
        xpc_release(reply);
        errno = err;
        return -1;
    }

    int fd = xpc_dictionary_dup_fd(reply, "fd");
    xpc_release(reply);
    return fd;
}

int PosixIOInterfaceRouted::stat(const char *_path, struct stat *_st)
{ 
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::stat(_path, _st);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "stat");
    xpc_dictionary_set_string(message, "path", _path);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::stat(_path, _st);
    }
    
    if( int err = (int)xpc_dictionary_get_int64(reply, "error") ) {
        // got a graceful error, propaganate it
        xpc_release(reply);
        errno = err;
        return -1;
    }
    
    size_t st_size;
    const void *v = xpc_dictionary_get_data(reply, "st", &st_size);
    if( v == nullptr || st_size != sizeof(struct stat) ) {
        // invalid reply, return
        xpc_release(reply);
        errno = EIO;
        return -1;
    }
    
    memcpy(_st, v, st_size);
    return 0;
}

int PosixIOInterfaceRouted::lstat(const char *_path, struct stat *_st)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::lstat(_path, _st);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "lstat");
    xpc_dictionary_set_string(message, "path", _path);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::PosixIOInterfaceNative::lstat(_path, _st);
    }
    
    if( int err = (int)xpc_dictionary_get_int64(reply, "error") ) {
        // got a graceful error, propaganate it
        xpc_release(reply);
        errno = err;
        return -1;
    }
    
    size_t st_size;
    const void *v = xpc_dictionary_get_data(reply, "st", &st_size);
    if(v == nullptr || st_size != sizeof(struct stat)) {
        // invalid reply, return
        xpc_release(reply);
        errno = EIO;
        return -1;
    }
    
    memcpy(_st, v, st_size);
    return 0;
}

int	PosixIOInterfaceRouted::close(int _fd)
{
    // some juggling with fds state will come later
    return super::close(_fd);
}

DIR *PosixIOInterfaceRouted::opendir(const char *_path)
{
    if(!inst.Enabled())
        return super::opendir(_path);
    
    int fd = this->open(_path, O_RDONLY | O_NONBLOCK | O_DIRECTORY | O_CLOEXEC, 0);
    if(fd < 0)
        return nullptr;
    
    return fdopendir(fd);
}

int	PosixIOInterfaceRouted::mkdir(const char *_path, mode_t _mode)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::mkdir(_path, _mode);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "mkdir");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "mode", _mode);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::mkdir(_path, _mode);
    }
    
    if( int err = (int)xpc_dictionary_get_int64(reply, "error") ) {
        // got a graceful error, propaganate it
        xpc_release(reply);
        errno = err;
        return -1;
    }
    
    if( xpc_dictionary_get_bool(reply, "ok") != true ) {
        xpc_release(reply);
        errno = EIO;
        return -1;
    }
    
    xpc_release(reply);
    
    // at this point a directory was made by root account, need to fix up ownage
    this->chown(_path, g_UID, -1);
    
    return 0;
}

int PosixIOInterfaceRouted::chown(const char *_path, uid_t _uid, gid_t _gid)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::chown(_path, _uid, _gid);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "chown");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "uid", _uid);
    xpc_dictionary_set_int64 (message, "gid", _gid);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::chown(_path, _uid, _gid);
    }
    
    if( int err = (int)xpc_dictionary_get_int64(reply, "error") ) {
        // got a graceful error, propaganate it
        xpc_release(reply);
        errno = err;
        return -1;
    }
    
    if( xpc_dictionary_get_bool(reply, "ok") != true ) {
        xpc_release(reply);
        errno = EIO;
        return -1;
    }
    
    xpc_release(reply);    
    return 0;
}

int PosixIOInterfaceRouted::rmdir(const char *_path)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::rmdir(_path);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "rmdir");
    xpc_dictionary_set_string(message, "path", _path);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::rmdir(_path);
    }
    
    if( int err = (int)xpc_dictionary_get_int64(reply, "error") ) {
        // got a graceful error, propaganate it
        xpc_release(reply);
        errno = err;
        return -1;
    }
    
    if( xpc_dictionary_get_bool(reply, "ok") != true ) {
        xpc_release(reply);
        errno = EIO;
        return -1;
    }
    
    xpc_release(reply);
    return 0;
}

int PosixIOInterfaceRouted::unlink(const char *_path)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::unlink(_path);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "unlink");
    xpc_dictionary_set_string(message, "path", _path);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::unlink(_path);
    }
    
    if( int err = (int)xpc_dictionary_get_int64(reply, "error") ) {
        // got a graceful error, propaganate it
        xpc_release(reply);
        errno = err;
        return -1;
    }
    
    if( xpc_dictionary_get_bool(reply, "ok") != true ) {
        xpc_release(reply);
        errno = EIO;
        return -1;
    }
    
    xpc_release(reply);
    return 0;
}
