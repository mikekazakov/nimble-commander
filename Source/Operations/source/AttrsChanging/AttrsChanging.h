// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Operation.h"
#include "Options.h"

namespace nc::ops {

class AttrsChangingJob;

class AttrsChanging : public Operation
{
public:
    AttrsChanging(AttrsChangingCommand _command);
    ~AttrsChanging();

private:
    virtual Job *GetJob() noexcept override;
    int OnSourceAccessError(Error _err, const std::string &_path, VFSHost &_vfs);
    int OnChmodError(Error _err, const std::string &_path, VFSHost &_vfs);
    int OnChownError(Error _err, const std::string &_path, VFSHost &_vfs);
    int OnFlagsError(Error _err, const std::string &_path, VFSHost &_vfs);
    int OnTimesError(Error _err, const std::string &_path, VFSHost &_vfs);

    std::unique_ptr<AttrsChangingJob> m_Job;
    bool m_SkipAll = false;
};

} // namespace nc::ops
