//
//  VFSPSFile.h
//  Files
//
//  Created by Michael G. Kazakov on 27.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

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
