//
//  FileLinkOperation.m
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "../../OperationDialogAlert.h"
#include "FileLinkOperation.h"
#include "FileLinkOperationJob.h"

@implementation FileLinkOperation
{
    FileLinkOperationJob m_Job;
}

- (id) initWithNewSymbolinkLink: (const char*) _source
                       linkname: (const char*) _name
{
    self = [super initWithJob:&m_Job];
    if (self) {
        m_Job.Init(_source, _name, FileLinkOperationJob::Mode::CreateSymLink, self);
        self.Caption = NSLocalizedStringFromTable(@"Creating a new symbolic link", @"Operations",
                                                  "Operation title for symlink creation");
    }
    return self;
}

- (id) initWithAlteringOfSymbolicLink: (const char*) _source
                             linkname: (const char*) _name
{
    self = [super initWithJob:&m_Job];
    if (self) {
        m_Job.Init(_source, _name, FileLinkOperationJob::Mode::AlterSymlink, self);
        self.Caption = NSLocalizedStringFromTable(@"Altering symbolic link", @"Operations",
                                                  "Operation title for symlink altering");
    }
    return self;
}

- (id) initWithNewHardLink: (const char*) _source
                  linkname: (const char*) _name
{
    self = [super initWithJob:&m_Job];
    if (self) {
        m_Job.Init(_source, _name, FileLinkOperationJob::Mode::CreateHardLink, self);
        self.Caption = NSLocalizedStringFromTable(@"Creating a new hard link", @"Operations",
                                                  "Operation title for hardlink creation");
    }
    return self;
}

- (OperationDialogAlert *)errorDialogWithRetryAbortHide:(NSError*)_error andTitle:(NSString*)_title
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:_title];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@", @"Operations",
                                                                                    "Generic informative error text"),
                               _error.localizedDescription]];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Retry", @"Operations", "User action button title")
                    andResult:OperationDialogResult::Retry];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Abort", @"Operations", "User action button title")
                    andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Hide", @"Operations", "User action button title")
                    andResult:OperationDialogResult::None];
    return alert;
}

- (OperationDialogAlert *)DialogNewSymlinkError:(NSError*)_error
{
    OperationDialogAlert *alert = [self errorDialogWithRetryAbortHide:_error
                                                             andTitle:NSLocalizedStringFromTable(@"Failed to create a symbolic link",
                                                                                                 @"Operations",
                                                                                                 "Error dialog title on symlink creation failure")
                                   ];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogAlterSymlinkError:(NSError*)_error
{
    OperationDialogAlert *alert = [self errorDialogWithRetryAbortHide:_error
                                                             andTitle:NSLocalizedStringFromTable(@"Failed to alter a symbolic link",
                                                                                                 @"Operations",
                                                                                                 "Error dialog title on symlink altering failure")
                                   ];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogNewHardlinkError:(NSError*)_error
{
    OperationDialogAlert *alert = [self errorDialogWithRetryAbortHide:_error
                                                             andTitle:NSLocalizedStringFromTable(@"Failed to create a hard link",
                                                                                                 @"Operations",
                                                                                                 "Error dialog title on hardlink creation failure")
                                   ];
    [self EnqueueDialog:alert];
    return alert;
}

@end
