// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Operation.h"
#include <VFS/VFS.h>

namespace nc::ops {

class DirectoryCreationJob;

class DirectoryCreation final : public Operation
{
public:
    DirectoryCreation( std::string _directory_name, std::string _root_folder, VFSHost &_vfs );
    ~DirectoryCreation();

    const std::vector<std::string> &DirectoryNames() const;

private:
    virtual Job *GetJob() noexcept override;
    int OnError(int _err, const std::string &_path, VFSHost &_vfs);

    std::vector<std::string> m_Directories;
    std::unique_ptr<DirectoryCreationJob> m_Job;
};

}
