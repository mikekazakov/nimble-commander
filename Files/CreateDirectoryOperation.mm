//
//  CreateDirectoryOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "CreateDirectoryOperation.h"
#import "CreateDirectoryOperationJob.h"
#import "CreateDirectoryOperationVFSJob.h"
#import "PanelController.h"
#import "Common.h"

@implementation CreateDirectoryOperation
{
    unique_ptr<CreateDirectoryOperationJob> m_NativeJob;
    unique_ptr<CreateDirectoryOperationVFSJob> m_VFSJob;
    string m_OriginalPathRequest;
    uint64_t m_OperationStart;

}

- (id)initWithPath:(const char*)_path rootpath:(const char*)_rootpath
{
    m_NativeJob = make_unique<CreateDirectoryOperationJob>();
    self = [super initWithJob:m_NativeJob.get()];
    if (self)
    {
        m_OriginalPathRequest = _path;
        m_OperationStart = GetTimeInNanoseconds();
        m_NativeJob->Init(_path, _rootpath, self);
        self.Caption = [NSString stringWithFormat:@"Creating directory \"%@\"",
                        [NSString stringWithUTF8String:_path]];
    }
    return self;
}

- (id)initWithPath:(const char*)_path rootpath:(const char*)_rootpath at:(const VFSHostPtr&)_host
{
    m_VFSJob = make_unique<CreateDirectoryOperationVFSJob>();
    self = [super initWithJob:m_VFSJob.get()];
    if (self)
    {
        m_OriginalPathRequest = _path;
        m_OperationStart = GetTimeInNanoseconds();
        m_VFSJob->Init(_path, _rootpath, _host, self);
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

- (OperationDialogAlert *)DialogOnCrDirVFSError:(int)_error
                                         ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:NO];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to create directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nPath: %@",
                               VFSError::ToNSError(_error).localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (void) OnFinish
{
    [super OnFinish];
    
    const uint64_t op_time_thresh = 500 * USEC_PER_SEC; // if operation was done in 500ms - we will ask panel to change cursor
        
    if(self.TargetPanel != nil && (GetTimeInNanoseconds() - m_OperationStart < op_time_thresh) )
    {
        if(m_OriginalPathRequest.find('/') == string::npos)
        {
            // select new entry only if it was a short path
            PanelController *target = self.TargetPanel;
            
            dispatch_to_main_queue( ^{
                [target RefreshDirectory];
                [target ScheduleDelayedSelectionChangeFor:m_OriginalPathRequest
                                                timeoutms:500
                                                 checknow:true];
                });
        }
    }
}

@end
