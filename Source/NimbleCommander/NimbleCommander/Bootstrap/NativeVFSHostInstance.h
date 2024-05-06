// Copyright (C) 2020 Michael Kazakov. Subject to GNU General Public License version 3.

// this facility is a temporary solution to get rid of NativeHost's singleton in VFS.
// MUST be removed, all client code relying on it must be refactored to state this dependency
// explicitly.

#include <VFS/Native.h>

namespace nc::bootstrap {

nc::vfs::NativeHost &NativeVFSHostInstance() noexcept;

}
