#pragma once

#include "../Job.h"
#include <VFS/VFS.h>

namespace nc::ops {

class DirectoryCreationJob : public Job
{
public:
    DirectoryCreationJob( const vector<string> &_directories_chain,
                         const string &_root_folder,
                         const VFSHostPtr &_vfs );
    ~DirectoryCreationJob();
    
private:
    virtual void Perform() override;

    const vector<string> &m_DirectoriesChain;
    string m_RootFolder;
    VFSHostPtr m_VFS;
};

}
