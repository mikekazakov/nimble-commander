// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../include/RoutedIO/RoutedIO.h"

class PosixIOInterfaceNative : public PosixIOInterface
{
public:
    virtual bool isrouted() const override;
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
    virtual int chflags(const char *_path, u_int _flags) override;
    virtual int link(const char *_path_exist, const char *_path_newnode) override;
    virtual int chmod(const char *_path, mode_t _mode) override;
    virtual int chmtime(const char *_path, time_t _time) override;
    virtual int chctime(const char *_path, time_t _time) override;
    virtual int chbtime(const char *_path, time_t _time) override;
    virtual int chatime(const char *_path, time_t _time) override;
    virtual int killpg(int _pid, int _signal) override;
private:
    int ApplyTimeChange(const char *_path, time_t _time, uint32_t _attr);
};

class PosixIOInterfaceRouted : public PosixIOInterfaceNative
{
public:
    PosixIOInterfaceRouted(RoutedIO &_inst);
    virtual bool isrouted() const override;
    virtual int open(const char *_path, int _flags, int _mode) override;
    virtual int	close(int _fd) override;
    virtual DIR *opendir(const char *_path) override;
    virtual int stat(const char *_path, struct stat *_st) override;
    virtual int lstat(const char *_path, struct stat *_st) override;
    virtual int	mkdir(const char *_path, mode_t _mode) override;
    virtual int chown(const char *_path, uid_t _uid, gid_t _gid) override;
    virtual int chflags(const char *_path, u_int _flags) override;
    virtual int rmdir(const char *_path) override;
    virtual int unlink(const char *_path) override;
    virtual int rename(const char *_old, const char *_new) override;
    virtual ssize_t readlink(const char *_path, char *_symlink, size_t _buf_sz) override;
    virtual int symlink(const char *_value, const char *_symlink_path) override;
    virtual int link(const char *_path_exist, const char *_path_newnode) override;
    virtual int chmod(const char *_path, mode_t _mode) override;
    virtual int chmtime(const char *_path, time_t _time) override;
    virtual int chctime(const char *_path, time_t _time) override;
    virtual int chbtime(const char *_path, time_t _time) override;
    virtual int chatime(const char *_path, time_t _time) override;
    virtual int killpg(int _pid, int _signal) override;
private:
    xpc_connection_t Connection();
    typedef PosixIOInterfaceNative super;
    RoutedIO &inst;
};
