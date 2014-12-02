//
//  RoutedIOInterfaces.h
//  Files
//
//  Created by Michael G. Kazakov on 29/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "RoutedIO.h"

class PosixIOInterfaceNative : public PosixIOInterface
{
public:
    virtual int open(const char *_path, int _flags, int _mode) override;
    virtual int	close(int _fd) override;
    virtual ssize_t read(int _fildes, void *_buf, size_t _nbyte) override;
    virtual ssize_t write(int _fildes, const void *_buf, size_t _nbyte) override;
    virtual off_t lseek(int _fd, off_t _offset, int _whence) override;
    virtual DIR *opendir(const char *_path) override;
    virtual int closedir(DIR *) override;
    virtual struct dirent *readdir(DIR *) override;
    virtual int stat(const char *_path, struct stat *_st) override;
    virtual int lstat(const char *_path, struct stat *_st) override;
    virtual int	mkdir(const char *_path, mode_t _mode) override;
    virtual int chown(const char *_path, uid_t _uid, gid_t _gid) override;
    virtual int rmdir(const char *_path) override;
    virtual int unlink(const char *_path) override;
    virtual int rename(const char *_old, const char *_new) override;
    virtual ssize_t readlink(const char *_path, char *_symlink, size_t _buf_sz) override;
    virtual int symlink(const char *_value, const char *_symlink_path) override;
};

class PosixIOInterfaceRouted : public PosixIOInterfaceNative
{
public:
    PosixIOInterfaceRouted(RoutedIO &_inst);
    virtual int open(const char *_path, int _flags, int _mode) override;
    virtual int	close(int _fd) override;
    virtual DIR *opendir(const char *_path) override;
    virtual int stat(const char *_path, struct stat *_st) override;
    virtual int lstat(const char *_path, struct stat *_st) override;
    virtual int	mkdir(const char *_path, mode_t _mode) override;
    virtual int chown(const char *_path, uid_t _uid, gid_t _gid) override;
    virtual int rmdir(const char *_path) override;
    virtual int unlink(const char *_path) override;
    virtual int rename(const char *_old, const char *_new) override;
    virtual ssize_t readlink(const char *_path, char *_symlink, size_t _buf_sz) override;
    virtual int symlink(const char *_value, const char *_symlink_path) override;
private:
    xpc_connection_t Connection();
    typedef PosixIOInterfaceNative super;
    RoutedIO &inst;
};
