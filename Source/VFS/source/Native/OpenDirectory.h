// Copyright (C) 2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFSDeclarations.h>
#include <Base/Error.h>
#include <expected>

namespace nc::vfs::native {

std::expected<std::vector<VFSUser>, Error> FetchUsers();

std::expected<std::vector<VFSGroup>, Error> FetchGroups();

} // namespace nc::vfs::native
