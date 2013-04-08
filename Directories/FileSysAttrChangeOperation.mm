//
//  FileSysAttrChangeOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileSysAttrChangeOperation.h"
#include "FileSysAttrChangeOperationJob.h"

@implementation FileSysAttrChangeOperation
{
    FileSysAttrChangeOperationJob m_Job;
}

- (id)initWithCommand:(FileSysAttrAlterCommand*)_command
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_command, self);
    
    }
    return self;
}

- (NSString *)GetCaption
{
    unsigned items_total, item_no;
    FileSysAttrChangeOperationJob::State state = m_Job.StateDetail(item_no, items_total);
    switch(state)
    {
        case FileSysAttrChangeOperationJob::StateScanning: return @"Scanning...";
        case FileSysAttrChangeOperationJob::StateSetting:
            return [NSString stringWithFormat:@"Processing file %d of %d.", item_no, items_total];
        default: return @"";
    }
}

- (OperationDialogAlert *)DialogOnChmodError:(int)_error
                                   ForFile:(const char *)_path
                                  WithMode:(mode_t)_mode
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Chmod Error"];
    char buff[12];
    strmode(_mode, buff);
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nFile: %s\nMode: %s",
        strerror(_error), _path, buff]];
    
    [alert AddButtonWithTitle:@"Retry"
                    andResult:FileSysAttrChangeOperationDialogResult::Retry];
    [alert AddButtonWithTitle:@"Skip" andResult:OperationDialogResult::Continue];
    [alert AddButtonWithTitle:@"Skip All"
                    andResult:FileSysAttrChangeOperationDialogResult::SkipAll];
    [alert AddButtonWithTitle:@"Stop" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnChflagsError:(int)_error
                                     ForFile:(const char*)_path
                                   WithFlags:(uint32_t)_flags
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Chflags Error"];
    char *str = fflagstostr(_flags);
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nFile: %s\nFlags: %s",
                               strerror(_error), _path, str]];
    free(str);

    [alert AddButtonWithTitle:@"Retry"
                    andResult:FileSysAttrChangeOperationDialogResult::Retry];
    [alert AddButtonWithTitle:@"Skip" andResult:OperationDialogResult::Continue];
    [alert AddButtonWithTitle:@"Skip All"
                    andResult:FileSysAttrChangeOperationDialogResult::SkipAll];
    [alert AddButtonWithTitle:@"Stop" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnChownError:(int)_error ForFile:(const char *)_path Uid:(uid_t)_uid Gid:(gid_t)_gid
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];

    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Chown Error"];
    [alert SetInformativeText:
        [NSString stringWithFormat:@"Can't change owner and/or group.\nError: %s\nFile: %s",
         strerror(_error), _path]];
    
    [alert AddButtonWithTitle:@"Retry"
                    andResult:FileSysAttrChangeOperationDialogResult::Retry];
    [alert AddButtonWithTitle:@"Skip" andResult:OperationDialogResult::Continue];
    [alert AddButtonWithTitle:@"Skip All"
                    andResult:FileSysAttrChangeOperationDialogResult::SkipAll];
    [alert AddButtonWithTitle:@"Stop" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
