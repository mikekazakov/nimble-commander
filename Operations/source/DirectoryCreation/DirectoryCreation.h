#pragma once

#include "../Operation.h"
#include <VFS/VFS.h>

namespace nc::ops {

class DirectoryCreationJob;

class DirectoryCreation : public Operation
{
public:
    DirectoryCreation( string _directory_name, string _root_folder, VFSHost &_vfs );
    ~DirectoryCreation();

    const vector<string> &DirectoryNames() const;

private:
    virtual Job *GetJob() noexcept override;
    void OnError(int _err, const string &_path, VFSHost &_vfs);

    vector<string> m_Directories;
    unique_ptr<DirectoryCreationJob> m_Job;
};

}
