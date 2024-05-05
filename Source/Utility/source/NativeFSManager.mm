// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NativeFSManager.h"

namespace nc::utility {

/* this is here to ensure a proper interaction with ObjC members when called from a pure C++ code */
NativeFileSystemInfo::NativeFileSystemInfo() = default;
NativeFileSystemInfo::~NativeFileSystemInfo() = default;

} // namespace nc::utility
