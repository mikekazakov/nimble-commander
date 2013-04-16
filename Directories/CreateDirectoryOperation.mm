//
//  CreateDirectoryOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "CreateDirectoryOperation.h"
#include "CreateDirectoryOperationJob.h"

@implementation CreateDirectoryOperation
{
    CreateDirectoryOperationJob m_Job;
    

}

- (id)initWithPath:(const char*)_path rootpath:(const char*)_rootpath
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_path, _rootpath, self);
        self.Caption = [NSString stringWithFormat:@"Creating directory '%@'",
                        [NSString stringWithUTF8String:_path]];
    }
    return self;
}

- (OperationDialogAlert *)DialogOnCrDirError:(int)_error
                                      ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:NO];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to create directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}



@end
