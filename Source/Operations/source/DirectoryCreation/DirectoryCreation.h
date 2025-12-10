// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Operation.h"
#include <VFS/VFS.h>

namespace nc::ops {

class DirectoryCreationJob;
struct DirectoryCreationJobCallbacks;

class DirectoryCreation final : public Operation
{
public:
    DirectoryCreation(std::string _directory_name, std::string _root_folder, VFSHost &_vfs);
    ~DirectoryCreation();

    const std::vector<std::string> &DirectoryNames() const;

private:
    using Callbacks = DirectoryCreationJobCallbacks;

    virtual Job *GetJob() noexcept override;
    int OnError(Error _err, const std::string &_path, VFSHost &_vfs);
    static std::vector<std::string> Split(std::string_view _directory);

    std::vector<std::string> m_Directories;
    std::unique_ptr<DirectoryCreationJob> m_Job;
};

} // namespace nc::ops
