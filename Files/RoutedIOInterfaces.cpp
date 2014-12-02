//
//  RoutedIOInterfaces.cpp
//  Files
//
//  Created by Michael G. Kazakov on 29/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "RoutedIOInterfaces.h"

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

PosixIOInterfaceRouted::PosixIOInterfaceRouted(RoutedIO &_inst):
    inst(_inst)
{
}

int PosixIOInterfaceRouted::open(const char *_path, int _flags, int _mode)
{
    xpc_connection_t conn; // fallback to native on disabled routing or on helper connectity problems
    if(!inst.Enabled() || (conn = inst.Connection()) == nullptr)
        return PosixIOInterfaceNative::open(_path, _flags, _mode);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "open");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "flags", _flags);
    xpc_dictionary_set_int64 (message, "mode", _mode);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return PosixIOInterfaceNative::open(_path, _flags, _mode);
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
    xpc_connection_t conn; // fallback to native on disabled routing or on helper connectity problems
    if(!inst.Enabled() || (conn = inst.Connection()) == nullptr)
        return PosixIOInterfaceNative::stat(_path, _st);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "stat");
    xpc_dictionary_set_string(message, "path", _path);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return PosixIOInterfaceNative::PosixIOInterfaceNative::stat(_path, _st);
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

int PosixIOInterfaceRouted::lstat(const char *_path, struct stat *_st)
{
    xpc_connection_t conn; // fallback to native on disabled routing or on helper connectity problems
    if(!inst.Enabled() || (conn = inst.Connection()) == nullptr)
        return PosixIOInterfaceNative::lstat(_path, _st);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "lstat");
    xpc_dictionary_set_string(message, "path", _path);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return PosixIOInterfaceNative::PosixIOInterfaceNative::lstat(_path, _st);
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
    return PosixIOInterfaceNative::close(_fd);
}

DIR *PosixIOInterfaceRouted::opendir(const char *_path)
{
    if(!inst.Enabled())
        return PosixIOInterfaceNative::opendir(_path);
    
    int fd = open(_path, O_RDONLY | O_NONBLOCK | O_DIRECTORY | O_CLOEXEC, 0);
    if(fd < 0)
        return nullptr;
    
    return fdopendir(fd);
}
