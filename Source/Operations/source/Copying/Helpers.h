// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::ops::copying {
    
std::string FindNonExistingItemPath(const std::string &_orig_existing_path,
                                    VFSHost &_host,
                                    const VFSCancelChecker &_cancel_checker = nullptr);

}
