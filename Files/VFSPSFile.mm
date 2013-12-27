//
//  VFSPSFile.mm
//  Files
//
//  Created by Michael G. Kazakov on 27.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "VFSPSFile.h"

VFSPSFile::VFSPSFile(const char* _relative_path, shared_ptr<VFSHost> _host, const string &_file):
    VFSGenericMemReadOnlyFile(_relative_path,
                              _host,
                              _file.c_str(),
                              _file.length()),
    m_File(_file)
{
}
