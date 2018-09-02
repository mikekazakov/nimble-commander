// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PosixFilesystemImpl.h"
#include <stdio.h>

namespace nc::hbn {

PosixFilesystemImpl PosixFilesystemImpl::instance;
    
int PosixFilesystemImpl::close(int _fd)
{
    return ::close(_fd);
}

ssize_t PosixFilesystemImpl::write(int _fd, const void *_buf, size_t _nbyte)
{
    return ::write(_fd, _buf, _nbyte);
}

int PosixFilesystemImpl::unlink(const char *_path)
{
    return ::unlink(_path);
}
    
int PosixFilesystemImpl::mkstemp(char *_pattern)
{
    return ::mkstemp(_pattern);
}

int PosixFilesystemImpl::rename(const char *_old, const char *_new)
{
    return ::rename(_old, _new);
}

}
