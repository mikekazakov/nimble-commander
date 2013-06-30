//
//  FileLinkOperation.m
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileLinkOperation.h"
#import "FileLinkOperationJob.h"
#import "OperationDialogAlert.h"

@implementation FileLinkOperation
{
    FileLinkOperationJob m_Job;
}

- (id) initWithNewSymbolinkLink: (const char*) _source
                       linkname: (const char*) _name
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_source, _name, FileLinkOperationJob::Mode::CreateSymLink, self);
        self.Caption = @"Creating a new symbolic link";
    }
    return self;
}

- (id) initWithAlteringOfSymbolicLink: (const char*) _source
                             linkname: (const char*) _name
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_source, _name, FileLinkOperationJob::Mode::AlterSymlink, self);
        self.Caption = @"Altering symbolic link";
    }
    return self;
}

- (id) initWithNewHardLink: (const char*) _source
                  linkname: (const char*) _name
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_source, _name, FileLinkOperationJob::Mode::CreateHardLink, self);
        self.Caption = @"Creating a new hard link";        
    }
    return self;
}

- (OperationDialogAlert *)DialogNewSymlinkError:(NSError*)_error
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to create a symbolic link"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@", [_error localizedDescription]]];
    [alert AddButtonWithTitle:@"Retry" andResult:OperationDialogResult::Retry];
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogAlterSymlinkError:(NSError*)_error
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to alter a symbolic link"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@", [_error localizedDescription]]];
    [alert AddButtonWithTitle:@"Retry" andResult:OperationDialogResult::Retry];
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogNewHardlinkError:(NSError*)_error
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to create a hard link"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@", [_error localizedDescription]]];
    [alert AddButtonWithTitle:@"Retry" andResult:OperationDialogResult::Retry];
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
