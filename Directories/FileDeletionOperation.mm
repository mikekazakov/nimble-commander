//
//  FileDeletionOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileDeletionOperation.h"
#include "FileDeletionOperationJob.h"

@implementation FileDeletionOperation
{
    FileDeletionOperationJob m_Job;
    
}

- (id)initWithFiles:(FlexChainedStringsChunk*)_files // passing with ownership, operation will free it on finish
               type:(FileDeletionOperationType)_type
           rootpath:(const char*)_path
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_files, _type, _path);
        
        // TODO: make unique name based on arguments
        self.Caption = @"Deleting files";
    }
    return self;
}

- (void)Update
{
    float progress = m_Job.GetProgress();
    if (self.Progress != progress)
    {
        self.Progress = progress;
        
// TODO: code will be used for status info
//        unsigned items_total, item_no;
//        FileDeletionOperationJob::State state = m_Job.StateDetail(item_no, items_total);
//        if (state == FileDeletionOperationJob::StateDeleting)
//        {
//            self.Caption = [NSString stringWithFormat:@"Deleting item %d of %d.", item_no, items_total];
//        }
    }
}

@end
