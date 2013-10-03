//
//  CreateDirectoryOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "CreateDirectoryOperation.h"
#import "CreateDirectoryOperationJob.h"
#import "PanelController.h"
#import "Common.h"

@implementation CreateDirectoryOperation
{
    CreateDirectoryOperationJob m_Job;
    char m_OriginalPathRequest[MAXPATHLEN];
    uint64_t m_OperationStart;

}

- (id)initWithPath:(const char*)_path rootpath:(const char*)_rootpath
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        strcpy(m_OriginalPathRequest, _path);
        m_OperationStart = GetTimeInNanoseconds();
        m_Job.Init(_path, _rootpath, self);
        self.Caption = [NSString stringWithFormat:@"Creating directory \"%@\"",
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

- (void) Finished
{
    const uint64_t op_time_thresh = 500 * USEC_PER_SEC; // if operation was done in 500ms - we will ask panel to change cursor
    
    if(self.TargetPanel != nil && (GetTimeInNanoseconds() - m_OperationStart < op_time_thresh) )
    {
        if(strchr(m_OriginalPathRequest, '/') == 0)
        {
            // select new entry only if it was a short path
            NSString *path = [NSString stringWithUTF8String:m_OriginalPathRequest];
            PanelController *target = self.TargetPanel;
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [target ScheduleDelayedSelectionChangeFor:path
                                                timeoutms:500
                                                 checknow:true];
                });
        }
    }
}

@end
