// Copyright (C) 2021 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WriteAtomically.h"
#include <cerrno>
#include <unistd.h>

namespace nc::base {

bool WriteAtomically(const std::filesystem::path &_path, std::span<const std::byte> _bytes) noexcept
{
    if( _path.empty() || !_path.is_absolute() ) {
        errno = EINVAL;
        return false;
    }

    auto filename_temp = _path.native() + ".XXXXXX";
    const auto fd = mkstemp(filename_temp.data());
    if( fd < 0 )
        return false;

    ssize_t left = _bytes.size();
    const std::byte *ptr = _bytes.data();

    while( left > 0 ) {
        const auto write_rc = write(fd, ptr, left);
        if( write_rc >= 0 ) {
            left -= write_rc;
            ptr += write_rc;
        }
        else {
            close(fd);
            unlink(filename_temp.c_str());
            return false;
        }
    }

    close(fd);

    if( rename(filename_temp.c_str(), _path.c_str()) == 0 ) {
        return true;
    }
    else {
        unlink(filename_temp.c_str());
        return false;
    }
}

} // namespace nc::base
