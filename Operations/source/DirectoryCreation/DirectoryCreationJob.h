// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include <VFS/VFS.h>

namespace nc::ops {

struct DirectoryCreationJobCallbacks
{
    enum class ErrorResolution { Stop, Retry };
    function< ErrorResolution(int _err, const string &_path, VFSHost &_vfs) >
    m_OnError =
    [](int _err, const string &_path, VFSHost &_vfs){ return ErrorResolution::Stop; };
};

class DirectoryCreationJob final : public Job, public DirectoryCreationJobCallbacks
{
public:
    DirectoryCreationJob( const vector<string> &_directories_chain,
                         const string &_root_folder,
                         const VFSHostPtr &_vfs );
    ~DirectoryCreationJob();
    
private:
    virtual void Perform() override;
    bool MakeDir(const string &_path);

    const vector<string> &m_DirectoriesChain;
    string m_RootFolder;
    VFSHostPtr m_VFS;
};

}
