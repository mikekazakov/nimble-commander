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
    unique_ptr<AttrsChangingJob> m_Job;
};

}
