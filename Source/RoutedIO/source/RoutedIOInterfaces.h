// Copyright (C) 2014-2021 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../include/RoutedIO/RoutedIO.h"

namespace nc::routedio {

class PosixIOInterfaceNative : public PosixIOInterface
{
public:
    bool isrouted() const noexcept override;
    int open(const char *_path, int _flags, int _mode) noexcept override;
    int close(int _fd) noexcept override;
    ssize_t read(int _fildes, void *_buf, size_t _nbyte) noexcept override;
    ssize_t write(int _fildes, const void *_buf, size_t _nbyte) noexcept override;
    off_t lseek(int _fd, off_t _offset, int _whence) noexcept override;
    DIR *opendir(const char *_path) noexcept override;
    int closedir(DIR *) noexcept override;
    dirent *readdir(DIR *) noexcept override;
    int stat(const char *_path, struct stat *_st) noexcept override;
    int lstat(const char *_path, struct stat *_st) noexcept override;
    int mkdir(const char *_path, mode_t _mode) noexcept override;
    int chown(const char *_path, uid_t _uid, gid_t _gid) noexcept override;
    int rmdir(const char *_path) noexcept override;
    int unlink(const char *_path) noexcept override;
    int rename(const char *_old, const char *_new) noexcept override;
    ssize_t readlink(const char *_path, char *_symlink, size_t _buf_sz) noexcept override;
    int symlink(const char *_value, const char *_symlink_path) noexcept override;
    int chflags(const char *_path, u_int _flags) noexcept override;
    int lchflags(const char *_path, u_int _flags) noexcept override;
    int link(const char *_path_exist, const char *_path_newnode) noexcept override;
    int chmod(const char *_path, mode_t _mode) noexcept override;
    int chmtime(const char *_path, time_t _time) noexcept override;
    int chctime(const char *_path, time_t _time) noexcept override;
    int chbtime(const char *_path, time_t _time) noexcept override;
    int chatime(const char *_path, time_t _time) noexcept override;
    int killpg(int _pid, int _signal) noexcept override;
    int trash(const char *_path) noexcept override;

private:
    static int ApplyTimeChange(const char *_path, time_t _time, uint32_t _attr);
};

class PosixIOInterfaceRouted : public PosixIOInterfaceNative
{
public:
    PosixIOInterfaceRouted(RoutedIO &_inst);
    bool isrouted() const noexcept override;
    int open(const char *_path, int _flags, int _mode) noexcept override;
    int close(int _fd) noexcept override;
    DIR *opendir(const char *_path) noexcept override;
    int stat(const char *_path, struct stat *_st) noexcept override;
    int lstat(const char *_path, struct stat *_st) noexcept override;
    int mkdir(const char *_path, mode_t _mode) noexcept override;
    int chown(const char *_path, uid_t _uid, gid_t _gid) noexcept override;
    int chflags(const char *_path, u_int _flags) noexcept override;
    int lchflags(const char *_path, u_int _flags) noexcept override;
    int rmdir(const char *_path) noexcept override;
    int unlink(const char *_path) noexcept override;
    int rename(const char *_old, const char *_new) noexcept override;
    ssize_t readlink(const char *_path, char *_symlink, size_t _buf_sz) noexcept override;
    int symlink(const char *_value, const char *_symlink_path) noexcept override;
    int link(const char *_path_exist, const char *_path_newnode) noexcept override;
    int chmod(const char *_path, mode_t _mode) noexcept override;
    int chmtime(const char *_path, time_t _time) noexcept override;
    int chctime(const char *_path, time_t _time) noexcept override;
    int chbtime(const char *_path, time_t _time) noexcept override;
    int chatime(const char *_path, time_t _time) noexcept override;
    int killpg(int _pid, int _signal) noexcept override;
    int trash(const char *_path) noexcept override;

private:
    xpc_connection_t Connection();
    typedef PosixIOInterfaceNative super;
    RoutedIO &inst;
};

} // namespace nc::routedio
