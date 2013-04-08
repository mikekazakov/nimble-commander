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

- (OperationDialogAlert *)DialogChmodError:(int)_error
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
    
    [alert AddButtonWithTitle:@"Skip" andResult:OperationDialogResultContinue];
    [alert AddButtonWithTitle:@"Skip All" andResult:FileSysAttrChangeOperationDialogSkipAll];
    [alert AddButtonWithTitle:@"Stop" andResult:OperationDialogResultStop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResultNone];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
