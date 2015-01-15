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

static NSString *OperationTitleFromPath(const char *_path)
{
    return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Creating directory \u201c%@\u201d",
                                                                 @"Operations",
                                                                 "Operation title prefix for directory creation"),
            [NSString stringWithUTF8String:_path]
            ];
}

@implementation CreateDirectoryOperation
{
    unique_ptr<CreateDirectoryOperationJob> m_NativeJob;
    unique_ptr<CreateDirectoryOperationVFSJob> m_VFSJob;
    string m_OriginalPathRequest;
    nanoseconds m_OperationStart;

}

- (id)initWithPath:(const char*)_path rootpath:(const char*)_rootpath
{
    m_NativeJob = make_unique<CreateDirectoryOperationJob>();
    self = [super initWithJob:m_NativeJob.get()];
    if (self) {
        m_OriginalPathRequest = _path;
        m_OperationStart = machtime();
        m_NativeJob->Init(_path, _rootpath, self);
        self.Caption = OperationTitleFromPath(_path);
    }
    return self;
}

- (id)initWithPath:(const char*)_path rootpath:(const char*)_rootpath at:(const VFSHostPtr&)_host
{
    m_VFSJob = make_unique<CreateDirectoryOperationVFSJob>();
    self = [super initWithJob:m_VFSJob.get()];
    if (self) {
        m_OriginalPathRequest = _path;
        m_OperationStart = machtime();
        m_VFSJob->Init(_path, _rootpath, _host, self);
        self.Caption = OperationTitleFromPath(_path);
    }
    return self;
}

- (OperationDialogAlert *)dialogOnDirCreationFailed:(NSError*)_error forDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:NO];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to create directory",
                                                     @"Operations",
                                                     "Error dialog title on directory creating failure")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nPath: %@",
                                                                                    @"Operations",
                                                                                    "Error dialog informative text on directory creating failure"),
                               _error.localizedDescription,
                               [NSString stringWithUTF8String:_path]]
     ];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (void) OnFinish
{
    [super OnFinish];
    
    // if operation was done in 500ms - we will ask panel to change cursor
    if(self.TargetPanel != nil && (machtime() - m_OperationStart < 500ms) )
    {
        if(m_OriginalPathRequest.find('/') == string::npos)
        {
            // select new entry only if it was a short path
            PanelController *target = self.TargetPanel;
            
            dispatch_to_main_queue( [=]{
                [target RefreshDirectory];
                PanelControllerDelayedSelection req;
                req.filename = m_OriginalPathRequest;
                [target ScheduleDelayedSelectionChangeFor:req
                                                 checknow:true];
                });
        }
    }
}

@end
