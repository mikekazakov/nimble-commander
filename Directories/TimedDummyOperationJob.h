//
//  TimedDummyOperationJob.h
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#ifndef __Directories__TimedDummyOperationJob__
#define __Directories__TimedDummyOperationJob__

#import "OperationJob.h"

@class TimedDummyOperation;

class TimedDummyOperationJob : public OperationJob
{
public:
    TimedDummyOperationJob();
    
    void Init(TimedDummyOperation *_op, int _seconds);

protected:
    virtual void Do();
    
private:
    int m_CompleteTime;
    
    TimedDummyOperation *m_Operation;
    
};

#endif /* defined(__Directories__TimedDummyOperationJob__) */
