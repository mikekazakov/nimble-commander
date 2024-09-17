// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSGenericMemReadOnlyFile.h>
#include "Host.h"

namespace nc::vfs {

class PSFile : public GenericMemReadOnlyFile
{
public:
    PSFile(std::string_view _relative_path, std::shared_ptr<class Host> _host, const std::string &_file);
};

} // namespace nc::vfs
