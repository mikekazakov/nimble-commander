//
//  JobData.h
//  Directories
//
//  Created by Michael G. Kazakov on 01.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#include <vector>

class AbstractFileJob;


class JobData
{
public:
    JobData();
    ~JobData();

    AbstractFileJob *JobNo(int _pos) const;
    int NumberOfJobs() const;
    void AddJob(AbstractFileJob *_job); // FIFO order, transfer ownership to JobData, should be allocated with "new"

    void PurgeDoneJobs();
    
typedef std::vector<AbstractFileJob*> JobsT;
private:
    JobsT m_Jobs;
};
