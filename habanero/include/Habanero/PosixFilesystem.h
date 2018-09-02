// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <unistd.h>

namespace nc::hbn {
    
class PosixFilesystem
{
public:
    virtual ~PosixFilesystem() = default;  

    virtual int close(int _fd) = 0;
    virtual ssize_t write(int _fd, const void *_buf, size_t _nbyte) = 0;
    virtual int unlink(const char *_path) = 0;
    virtual int rename (const char *_old, const char *_new) = 0;    
    virtual int mkstemp(char *_pattern) = 0;
};    
    
}
