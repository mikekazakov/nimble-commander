// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Operation.h"
#include "Options.h"

namespace nc::ops {

class AttrsChangingJob;

class AttrsChanging : public Operation
{
public:
    AttrsChanging( AttrsChangingCommand _command );
    ~AttrsChanging();

private:
    virtual Job *GetJob() noexcept override;
    int OnSourceAccessError(int _err, const string &_path, VFSHost &_vfs);
    int OnChmodError(int _err, const string &_path, VFSHost &_vfs);
    int OnChownError(int _err, const string &_path, VFSHost &_vfs);
    int OnFlagsError(int _err, const string &_path, VFSHost &_vfs);
    int OnTimesError(int _err, const string &_path, VFSHost &_vfs);
    
    unique_ptr<AttrsChangingJob> m_Job;
    bool m_SkipAll = false;    
};

}
