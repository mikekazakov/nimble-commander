//
//  FileCopyOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileCopyOperation.h"
#import "FileCopyOperationJob.h"

@implementation FileCopyOperation
{
    FileCopyOperationJob m_Job;
}

- (id)initWithFiles:(FlexChainedStringsChunk*)_files // passing with ownership, operation will free it on finish
               root:(const char*)_root
               dest:(const char*)_dest
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_files, _root, _dest, self);
    }
    return self;
}



@end
