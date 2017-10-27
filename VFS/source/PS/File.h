// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFSGenericMemReadOnlyFile.h>
#include "Host.h"

namespace nc::vfs {

class PSFile : public VFSGenericMemReadOnlyFile
{
public:
    PSFile(const char* _relative_path, shared_ptr<class Host> _host, const string &_file);
};

}
