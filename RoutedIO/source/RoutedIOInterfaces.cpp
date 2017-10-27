// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <assert.h>
#include <stdio.h>
#include <stdint.h>
#include <stddef.h>
#include <unistd.h>
#include <ftw.h>
#include <dirent.h>
#include <signal.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>

#include "RoutedIOInterfaces.h"

static const uid_t g_UID = getuid();
static const gid_t g_GID = getgid();

// hack to access function from libc implementation directly.
// this func does readdir but without mutex locking
struct dirent	*_readdir_unlocked(DIR *, int) __DARWIN_INODE64(_readdir_unlocked);

// trivial wrappers
bool PosixIOInterfaceNative::isrouted() const { return false; }
int PosixIOInterfaceNative::open(const char *_path, int _flags, int _mode) { return ::open(_path, _flags, _mode); }
int	PosixIOInterfaceNative::close(int _fd) { return ::close(_fd); }
ssize_t PosixIOInterfaceNative::read(int _fildes, void *_buf, size_t _nbyte) { return ::read(_fildes, _buf, _nbyte); }
ssize_t PosixIOInterfaceNative::write(int _fildes, const void *_buf, size_t _nbyte) { return ::write(_fildes, _buf, _nbyte); }
off_t PosixIOInterfaceNative::lseek(int _fd, off_t _offset, int _whence) { return ::lseek(_fd, _offset, _whence); }
DIR *PosixIOInterfaceNative::opendir(const char *_path) { return ::opendir(_path); }
int PosixIOInterfaceNative::closedir(DIR *_dir) { return ::closedir(_dir); }
struct dirent *PosixIOInterfaceNative::readdir(DIR *_dir) { return ::_readdir_unlocked(_dir, 1); }
int PosixIOInterfaceNative::stat(const char *_path, struct stat *_st) { return ::stat(_path, _st); }
int PosixIOInterfaceNative::lstat(const char *_path, struct stat *_st) { return ::lstat(_path, _st); }
int	PosixIOInterfaceNative::mkdir(const char *_path, mode_t _mode) { return ::mkdir(_path, _mode); }
int	PosixIOInterfaceNative::chown(const char *_path, uid_t _uid, gid_t _gid) { return ::chown(_path, _uid, _gid); }
int PosixIOInterfaceNative::chflags(const char *_path, u_int _flags) { return ::chflags(_path, _flags); }
int PosixIOInterfaceNative::rmdir(const char *_path) { return ::rmdir(_path); }
int PosixIOInterfaceNative::unlink(const char *_path) { return ::unlink(_path); }
int PosixIOInterfaceNative::rename(const char *_old, const char *_new) { return ::rename(_old, _new); }
ssize_t PosixIOInterfaceNative::readlink(const char *_path, char *_symlink, size_t _buf_sz) { return ::readlink(_path, _symlink, _buf_sz); }
int PosixIOInterfaceNative::symlink(const char *_value, const char *_symlink_path) { return ::symlink(_value, _symlink_path); }
int PosixIOInterfaceNative::link(const char *_path_exist, const char *_path_newnode) { return ::link(_path_exist, _path_newnode); }
int PosixIOInterfaceNative::chmod(const char *_path, mode_t _mode) { return ::chmod(_path, _mode); }
int PosixIOInterfaceNative::chmtime(const char *_path, time_t _time) { return ApplyTimeChange(_path, _time, ATTR_CMN_MODTIME); }
int PosixIOInterfaceNative::chatime(const char *_path, time_t _time) { return ApplyTimeChange(_path, _time, ATTR_CMN_ACCTIME); }
int PosixIOInterfaceNative::chctime(const char *_path, time_t _time) { return ApplyTimeChange(_path, _time, ATTR_CMN_CHGTIME); }
int PosixIOInterfaceNative::chbtime(const char *_path, time_t _time) { return ApplyTimeChange(_path, _time, ATTR_CMN_CRTIME); }
int PosixIOInterfaceNative::killpg(int _pid, int _signal) { return ::killpg(_pid, _signal); }

int PosixIOInterfaceNative::ApplyTimeChange(const char *_path, time_t _time, uint32_t _attr)
{
    struct attrlist attrs;
    memset(&attrs, 0, sizeof(attrs));
    attrs.bitmapcount = ATTR_BIT_MAP_COUNT;
    attrs.commonattr = _attr;
    timespec time = {_time, 0};
    return setattrlist(_path, &attrs, &time, sizeof(time), 0);
}

PosixIOInterfaceRouted::PosixIOInterfaceRouted(RoutedIO &_inst):
    inst(_inst)
{
}

bool PosixIOInterfaceRouted::isrouted() const
{
    return inst.Enabled();
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
    
    bool need_owner_fixup = false;
    if( (_flags & O_CREAT) != 0 ) {
        // need to check if call will create a new file. if so - we'll need to later chown it to ourselves to mimic this call
        struct stat st;
        if( this->stat(_path, &st) != 0 )
            need_owner_fixup = true;
    }
    
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
    
    if( fd > 0 && need_owner_fixup)
        this->chown(_path, g_UID, -1);    
        
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

int PosixIOInterfaceRouted::chflags(const char *_path, u_int _flags)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::chflags(_path, _flags);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "chflags");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "flags", _flags);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::chflags(_path, _flags);
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

int PosixIOInterfaceRouted::rename(const char *_old, const char *_new)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::rename(_old, _new);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "rename");
    xpc_dictionary_set_string(message, "oldpath", _old);
    xpc_dictionary_set_string(message, "newpath", _new);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::rename(_old, _new);
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

ssize_t PosixIOInterfaceRouted::readlink(const char *_path, char *_symlink, size_t _buf_sz)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::readlink(_path, _symlink, _buf_sz);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "readlink");
    xpc_dictionary_set_string(message, "path", _path);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::readlink(_path, _symlink, _buf_sz);
    }
    
    if( int err = (int)xpc_dictionary_get_int64(reply, "error") ) {
        // got a graceful error, propaganate it
        xpc_release(reply);
        errno = err;
        return -1;
    }
    
    const char *value = xpc_dictionary_get_string(reply, "link");
    if(!value) {
        xpc_release(reply);
        errno = EIO;
        return -1;
    }
    
    size_t sz = strlen(value);
    strncpy(_symlink, value, _buf_sz);
    
    xpc_release(reply);

    return sz;
}

int PosixIOInterfaceRouted::symlink(const char *_value, const char *_symlink_path)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::symlink(_value, _symlink_path);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "symlink");
    xpc_dictionary_set_string(message, "path", _symlink_path);
    xpc_dictionary_set_string(message, "value", _value);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::symlink(_value, _symlink_path);
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

int PosixIOInterfaceRouted::link(const char *_path_exist, const char *_path_newnode)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::link(_path_exist, _path_newnode);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "link");
    xpc_dictionary_set_string(message, "exist", _path_exist);
    xpc_dictionary_set_string(message, "newnode", _path_newnode);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::link(_path_exist, _path_newnode);
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

int PosixIOInterfaceRouted::chmod(const char *_path, mode_t _mode)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::chmod(_path, _mode);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "chmod");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "mode", _mode);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::chmod(_path, _mode);
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

int PosixIOInterfaceRouted::chmtime(const char *_path, time_t _time)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::chmtime(_path, _time);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "chmtime");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "time", _time);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::chmtime(_path, _time);
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

int PosixIOInterfaceRouted::chatime(const char *_path, time_t _time)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::chatime(_path, _time);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "chatime");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "time", _time);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::chatime(_path, _time);
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

int PosixIOInterfaceRouted::chbtime(const char *_path, time_t _time)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::chbtime(_path, _time);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "chbtime");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "time", _time);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::chbtime(_path, _time);
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

int PosixIOInterfaceRouted::chctime(const char *_path, time_t _time)
{
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::chctime(_path, _time);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "chctime");
    xpc_dictionary_set_string(message, "path", _path);
    xpc_dictionary_set_int64 (message, "time", _time);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::chctime(_path, _time);
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

int PosixIOInterfaceRouted::killpg(int _pid, int _signal)
{
    
    xpc_connection_t conn = Connection();
    if(!conn) // fallback to native on disabled routing or on helper connectity problems
        return super::killpg(_pid, _signal);
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "operation", "killpg");
    xpc_dictionary_set_int64 (message, "pid", _pid);
    xpc_dictionary_set_int64 (message, "signal", _signal);
    
    xpc_object_t reply = xpc_connection_send_message_with_reply_sync(conn, message);
    xpc_release(message);
    
    if(xpc_get_type(reply) == XPC_TYPE_ERROR) {
        xpc_release(reply); // connection broken, faling back to native
        return super::killpg(_pid, _signal);
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
