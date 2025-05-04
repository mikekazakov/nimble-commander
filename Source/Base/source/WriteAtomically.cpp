// Copyright (C) 2021-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WriteAtomically.h"
#include <cerrno>
#include <unistd.h>

namespace nc::base {

std::expected<void, Error> WriteAtomically(const std::filesystem::path &_path,
                                           std::span<const std::byte> _bytes) noexcept
{
    if( _path.empty() || !_path.is_absolute() ) {
        return std::unexpected(Error{Error::POSIX, EINVAL});
    }

    // Open a temporary file next to the destination
    auto filename_temp = _path.native() + ".XXXXXX";
    const auto fd = mkstemp(filename_temp.data());
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
            unlink(filename_temp.c_str());
            return std::unexpected(Error{Error::POSIX, err});
        }
    }
    close(fd);

    // Rename into the destination atomically
    if( rename(filename_temp.c_str(), _path.c_str()) == 0 ) {
        return {};
    }
    else {
        const int err = errno;
        unlink(filename_temp.c_str());
        return std::unexpected(Error{Error::POSIX, err});
    }
}

} // namespace nc::base
