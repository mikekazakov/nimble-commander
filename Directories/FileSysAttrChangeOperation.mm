//
//  FileSysAttrChangeOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileSysAttrChangeOperation.h"
#include "FileSysAttrChangeOperationJob.h"

@implementation FileSysAttrChangeOperation
{
    FileSysAttrChangeOperationJob m_Job;
}

- (id)initWithCommand:(FileSysAttrAlterCommand*)_command
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_command);
    
    }
    return self;
}


@end
