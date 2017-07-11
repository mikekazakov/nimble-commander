#include "AttrsChanging.h"
#include "AttrsChangingJob.h"

namespace nc::ops {

AttrsChanging::AttrsChanging( AttrsChangingCommand _command )
{
    m_Job.reset( new AttrsChangingJob(move(_command)) );
}

AttrsChanging::~AttrsChanging()
{
}

Job *AttrsChanging::GetJob() noexcept
{
    return m_Job.get();
}

}

