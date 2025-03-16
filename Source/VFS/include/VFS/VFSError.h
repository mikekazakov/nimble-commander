// Copyright (C) 2013-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <string>
#include <Base/Error.h>
#include <expected>

namespace VFSError {
enum {
    // general error codes
    Ok = 0,            // operation was succesful
    InvalidCall = -3,  // object state is invalid for such call
    GenericError = -4, // generic(unknown) error has occured
};

// Transition, to be removed later
inline constexpr std::string_view ErrorDomain = "VFSError";
nc::Error ToError(int _vfs_error_code);

}; // namespace VFSError
