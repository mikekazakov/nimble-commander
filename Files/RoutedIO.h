//
//  RoutedIO.h
//  Files
//
//  Created by Michael G. Kazakov on 29/11/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <xpc/xpc.h>


class PosixIOInterface
{
public:
    virtual int open(const char *_path, int _flags, int _mode) = 0;
    virtual int	close(int _fd) = 0;
    virtual ssize_t write(int _fildes, const void *_buf, size_t _nbyte) = 0;
    virtual DIR *opendir(const char *_path) = 0;
    virtual struct dirent *readdir(DIR *_dir) = 0;
    virtual int closedir(DIR *_dir) = 0;
    virtual int stat(const char *_path, struct stat *_st) = 0;
    virtual int lstat(const char *_path, struct stat *_st) = 0;
};

class RoutedIO
{
public:
    static PosixIOInterface &Interface;
    
    RoutedIO();
    static RoutedIO& Instance();
    
    bool Enabled() const noexcept;
    bool TurnOn();
    bool AskToInstallHelper();
    bool IsHelperInstalled();
    bool IsHelperCurrent();
    bool IsHelperAlive();
    xpc_connection_t Connection();
    
private:
    RoutedIO(RoutedIO&) = delete;
    void operator=(RoutedIO&) = delete;
    bool Connect();
    bool ConnectionAvailable();
  
    bool             m_Enabled    = false;
    xpc_connection_t m_Connection = nullptr;
};

inline bool RoutedIO::Enabled() const noexcept
{
    return m_Enabled;
}
