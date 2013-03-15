//
//  JobData.cpp
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <assert.h>
#include "JobData.h"
#include "FileOp.h"

// TODO: put a lof of Mutexes here!!!

JobData::JobData()
{
    m_Jobs.reserve(32); // hope that will be enough till the end of all days
    
    
}

JobData::~JobData()
{
    
    
}

int JobData::NumberOfJobs() const
{
    return (int)m_Jobs.size();
}

AbstractFileJob *JobData::JobNo(int _pos) const
{
    assert(_pos >= 0 && _pos < m_Jobs.size());
    return m_Jobs[_pos];
}

void JobData::AddJob(AbstractFileJob *_job)
{
    m_Jobs.push_back(_job);
}

void JobData::PurgeDoneJobs()
{
    for(auto i = m_Jobs.begin(); i < m_Jobs.end(); ++i)
        if((*i)->IsReadyToPurge())
        {
            AbstractFileJob *a = *i;
            delete a;
            
            m_Jobs.erase(i);
            PurgeDoneJobs();
            return;
        }
    
}