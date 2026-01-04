// Copyright (C) 2021-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Trash.h"
#include <Foundation/Foundation.h>
#include <Base/CFPtr.h>
#include <string_view>

namespace nc::routedio {

int TrashItemAtPath(const char *_path) noexcept
{
    const auto url = nc::base::CFPtr<CFURLRef>::adopt(CFURLCreateFromFileSystemRepresentation(
        nullptr, reinterpret_cast<const UInt8 *>(_path), std::string_view{_path}.length(), false));

    if( !url ) {
        errno = ENOENT;
        return -1;
    }

    NSError *error;
    const auto result = [NSFileManager.defaultManager trashItemAtURL:(__bridge NSURL *)url.get()
                                                    resultingItemURL:nil
                                                               error:&error];

    if( result ) {
        return 0;
    }
    else {
        if( error != nil && [error.domain isEqualToString:NSPOSIXErrorDomain] ) {
            errno = static_cast<int>(error.code);
        }
        else {
            errno = EPERM;
        }
        return -1;
    }
}

} // namespace nc::routedio
