// Copyright (C) 2021-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WriteAtomically.h"
#include "StackAllocator.h"
#include <cerrno>
#include <unistd.h>
#include <sys/stat.h>

namespace nc::base {

std::expected<void, Error> WriteAtomically(const std::filesystem::path &_path,
                                           std::span<const std::byte> _bytes,
                                           bool _follow_symlink) noexcept
{
    if( _path.empty() || !_path.is_absolute() ) {
        return std::unexpected(Error{Error::POSIX, EINVAL});
    }

    nc::StackAllocator alloc;
    std::pmr::string target_path(_path.c_str(), &alloc);

    if( _follow_symlink ) {
        // Try the read the real target path
        char actualpath[PATH_MAX + 1];
        if( realpath(_path.c_str(), actualpath) ) {
            target_path = actualpath;
        }
        else {
            // Non-existing entries are ok
            if( errno != ENOENT ) {
                return std::unexpected(Error{Error::POSIX, errno});
            }
        }
    }

    // Open a temporary file next to the destination
    std::pmr::string temp_path(target_path, &alloc);
    temp_path += ".XXXXXX";
    const auto fd = mkstemp(temp_path.data());
    if( fd < 0 )
        return std::unexpected(Error{Error::POSIX, errno});

    // Write the data into the temporary file
    ssize_t left = _bytes.size();
    const std::byte *ptr = _bytes.data();
    while( left > 0 ) {
        const auto write_rc = write(fd, ptr, left);
        if( write_rc >= 0 ) {
            left -= write_rc;
            ptr += write_rc;
        }
        else {
            const int err = errno;
            close(fd);
            unlink(temp_path.c_str());
            return std::unexpected(Error{Error::POSIX, err});
        }
    }
    close(fd);

    // Rename into the destination atomically
    if( rename(temp_path.c_str(), target_path.c_str()) == 0 ) {
        return {};
    }
    else {
        const int err = errno;
        unlink(temp_path.c_str());
        return std::unexpected(Error{Error::POSIX, err});
    }
}

} // namespace nc::base
