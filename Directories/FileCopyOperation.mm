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

- (OperationDialogAlert *)OnDestCantCreateDir:(int)_error ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to create directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %s",
                               strerror(_error), _path]];
    
    [alert AddButtonWithTitle:@"Retry" andResult:FileCopyOperationDR::Retry];
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantCreateDir:(int)_error ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to create directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %s",
                               strerror(_error), _path]];
    
    [alert AddButtonWithTitle:@"Retry" andResult:FileCopyOperationDR::Retry];
    if(!m_Job.IsSingleFileCopy())
    {
        [alert AddButtonWithTitle:@"Skip" andResult:FileCopyOperationDR::Skip];
        [alert AddButtonWithTitle:@"Skip All" andResult:FileCopyOperationDR::SkipAll];
    }
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];

    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantAccessSrcFile:(int)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to access file"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %s",
                               strerror(_error), _path]];
    
    [alert AddButtonWithTitle:@"Retry" andResult:FileCopyOperationDR::Retry];
    if(!m_Job.IsSingleFileCopy())
    {
        [alert AddButtonWithTitle:@"Skip" andResult:FileCopyOperationDR::Skip];
        [alert AddButtonWithTitle:@"Skip All" andResult:FileCopyOperationDR::SkipAll];
    }
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantOpenDestFile:(int)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to open file"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %s",
                               strerror(_error), _path]];
    
    [alert AddButtonWithTitle:@"Retry" andResult:FileCopyOperationDR::Retry];
    if(!m_Job.IsSingleFileCopy())
    {
        [alert AddButtonWithTitle:@"Skip" andResult:FileCopyOperationDR::Skip];
        [alert AddButtonWithTitle:@"Skip All" andResult:FileCopyOperationDR::SkipAll];
    }
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyReadError:(int)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Read error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %s",
                               strerror(_error), _path]];
    
    [alert AddButtonWithTitle:@"Retry" andResult:FileCopyOperationDR::Retry];
    if(!m_Job.IsSingleFileCopy())
    {
        [alert AddButtonWithTitle:@"Skip" andResult:FileCopyOperationDR::Skip];
        [alert AddButtonWithTitle:@"Skip All" andResult:FileCopyOperationDR::SkipAll];
    }
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyWriteError:(int)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Write error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %s",
                               strerror(_error), _path]];
    
    [alert AddButtonWithTitle:@"Retry" andResult:FileCopyOperationDR::Retry];
    if(!m_Job.IsSingleFileCopy())
    {
        [alert AddButtonWithTitle:@"Skip" andResult:FileCopyOperationDR::Skip];
        [alert AddButtonWithTitle:@"Skip All" andResult:FileCopyOperationDR::SkipAll];
    }
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
