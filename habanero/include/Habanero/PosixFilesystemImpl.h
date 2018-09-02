// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PosixFilesystem.h"

namespace nc::hbn {
    
class PosixFilesystemImpl : public PosixFilesystem
{
public:

    int close(int _fd) override;
    ssize_t write(int _fd, const void *_buf, size_t _nbyte) override;
    int unlink(const char *_path) override;
    int mkstemp(char *_pattern) override;
    int rename(const char *_old, const char *_new) override;
    
    static PosixFilesystemImpl instance;
};
        
}
