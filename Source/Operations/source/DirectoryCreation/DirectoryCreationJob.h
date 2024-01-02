// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include <VFS/VFS.h>

namespace nc::ops {

struct DirectoryCreationJobCallbacks
{
    enum class ErrorResolution { Stop, Retry };
    std::function< ErrorResolution(int _err, const std::string &_path, VFSHost &_vfs) >
    m_OnError = [](int, const std::string &, VFSHost &){ return ErrorResolution::Stop; };
};

class DirectoryCreationJob final : public Job, public DirectoryCreationJobCallbacks
{
public:
    DirectoryCreationJob( const std::vector<std::string> &_directories_chain,
                         const std::string &_root_folder,
                         const VFSHostPtr &_vfs );
    ~DirectoryCreationJob();
    
private:
    virtual void Perform() override;
    bool MakeDir(const std::string &_path);

    const std::vector<std::string> &m_DirectoriesChain;
    std::string m_RootFolder;
    VFSHostPtr m_VFS;
};

}
