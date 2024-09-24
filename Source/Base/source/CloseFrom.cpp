// Copyright (C) 2021-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/CloseFrom.h>
#include <algorithm>
#include <cassert>
#include <libproc.h>
#include <optional>
#include <unistd.h>
#include <vector>

namespace nc::base {

static const int g_MaxFD = static_cast<int>(sysconf(_SC_OPEN_MAX));

static std::optional<std::vector<proc_fdinfo>> GetFDs()
{
    const pid_t pid = getpid();
    const int size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nullptr, 0);
    if( size < 0 )
        return std::nullopt;

    assert(size % sizeof(proc_fdinfo) == 0);

    std::vector<proc_fdinfo> buf;
    buf.resize(size / sizeof(proc_fdinfo));

    const int result = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, buf.data(), size);
    if( result < 0 )
        return std::nullopt;
    assert(result % sizeof(proc_fdinfo) == 0);
    buf.resize(result / sizeof(proc_fdinfo));

    return buf;
}

void CloseFrom(int _lowfd) noexcept
{
    if( const auto fds = GetFDs() ) {
        for( auto &info : *fds ) {
            if( info.proc_fd >= _lowfd )
                close(info.proc_fd);
        }
    }
    else {
        for( int fd = _lowfd; fd != g_MaxFD; fd++ )
            close(fd);
    }
}

void CloseFromExcept(int _lowfd, int _except) noexcept
{
    if( const auto fds = GetFDs() ) {
        for( auto &info : *fds ) {
            if( info.proc_fd >= _lowfd && info.proc_fd != _except )
                close(info.proc_fd);
        }
    }
    else {
        for( int fd = _lowfd; fd != g_MaxFD; fd++ )
            if( fd != _except )
                close(fd);
    }
}

void CloseFromExcept(int _lowfd, std::span<const int> _except) noexcept
{
    const auto skip = [_except](int _fd) -> bool { return std::ranges::find(_except, _fd) != _except.end(); };
    if( const auto fds = GetFDs() ) {
        for( auto &info : *fds ) {
            if( info.proc_fd >= _lowfd && !skip(info.proc_fd) )
                close(info.proc_fd);
        }
    }
    else {
        for( int fd = _lowfd; fd != g_MaxFD; fd++ )
            if( !skip(fd) )
                close(fd);
    }
}

} // namespace nc::base
