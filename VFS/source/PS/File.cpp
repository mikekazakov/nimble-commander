// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"

namespace nc::vfs {

PSFile::PSFile(const char* _relative_path, shared_ptr<class Host> _host, const string &_file):
    VFSGenericMemReadOnlyFile(_relative_path,
                              _host,
                              _file.c_str(),
                              _file.length())
{
}

}
