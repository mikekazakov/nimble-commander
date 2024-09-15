// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "File.h"

namespace nc::vfs {

PSFile::PSFile(std::string_view _relative_path, std::shared_ptr<class Host> _host, const std::string &_file)
    : GenericMemReadOnlyFile(_relative_path, _host, _file.c_str(), _file.length())
{
}

} // namespace nc::vfs
