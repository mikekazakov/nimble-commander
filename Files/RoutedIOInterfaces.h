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
    virtual ssize_t write(int _fildes, const void *_buf, size_t _nbyte) override;
    virtual DIR *opendir(const char *_path) override;
    virtual int closedir(DIR *) override;
    virtual struct dirent *readdir(DIR *) override;
    virtual int stat(const char *_path, struct stat *_st) override;
    virtual int lstat(const char *_path, struct stat *_st) override;
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
private:
    RoutedIO &inst;
};

