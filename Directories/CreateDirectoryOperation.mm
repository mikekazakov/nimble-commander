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
    }
    return self;
}

- (OperationDialogAlert *)DialogOnCrDirError:(int)_error
                                      ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to create directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %s",
                               strerror(_error), _path]];

    [alert AddButtonWithTitle:@"Retry" andResult:CreateDirectoryOperationRetry];
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}



@end
