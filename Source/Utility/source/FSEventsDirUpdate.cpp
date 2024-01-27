// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "FSEventsDirUpdateImpl.h"

namespace nc::utility {

FSEventsDirUpdate &FSEventsDirUpdate::Instance() noexcept
{
    [[clang::no_destroy]] static FSEventsDirUpdateImpl inst;
    return inst;
}

} // namespace nc::utility
