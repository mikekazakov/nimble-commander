//
//  FileSysAttrChangeOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileSysAttrChangeOperation.h"
#import "FileSysAttrChangeOperationJob.h"
#import "Common.h"

#import <sys/attr.h>

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
        
        // Set caption.
        if (_command->files->amount == 1)
        {
            self.Caption = [NSString stringWithFormat:@"Altering attributes of \"%@\"",
                            [NSString stringWithUTF8String:_command->files->strings[0].str()]];
        }
        else
        {
            // Get directory name from path.
            char buff[128] = {0};
            GetDirectoryFromPath(_command->root_path, buff, 128);
            
            self.Caption = [NSString stringWithFormat:@"Altering attributes of %i items in \"%@\"",
                            _command->files->amount,
                            [NSString stringWithUTF8String:buff]];
        }
            
    }
    return self;
}

- (void)Update
{
    OperationStats &stats = m_Job.GetStats();
    float progress = stats.GetProgress();
    if (self.Progress != progress)
        self.Progress = progress;
    
    if (stats.IsCurrentItemChanged())
    {
        const char *item = stats.GetCurrentItem();
        if (!item)
            self.ShortInfo = @"";
        else
        {
            self.ShortInfo = [NSString stringWithFormat:@"Processing \"%@\"",
                              [NSString stringWithUTF8String:item]];
        }
    }
}

// TODO: code will be used for detailed status
//- (NSString *)GetCaption
//{
//    unsigned items_total, item_no;
//    FileSysAttrChangeOperationJob::State state = m_Job.StateDetail(item_no, items_total);
//    switch(state)
//    {
//        case FileSysAttrChangeOperationJob::StateScanning: return @"Scanning...";
//        case FileSysAttrChangeOperationJob::StateSetting:
//            return [NSString stringWithFormat:@"Processing file %d of %d.", item_no, items_total];
//        default: return @"";
//    }
//}

- (OperationDialogAlert *)DialogOnChmodError:(int)_error
                                   ForFile:(const char *)_path
                                  WithMode:(mode_t)_mode
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:YES];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Chmod Error"];
    char buff[12];
    strmode(_mode, buff);
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nFile: %@\nMode: %s",
                               strerror(_error), [NSString stringWithUTF8String:_path], buff]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnChflagsError:(int)_error
                                     ForFile:(const char*)_path
                                   WithFlags:(uint32_t)_flags
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:YES];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Chflags Error"];
    char *str = fflagstostr(_flags);
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nFile: %@\nFlags: %s",
                               strerror(_error), [NSString stringWithUTF8String:_path], str]];
    free(str);
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnChownError:(int)_error ForFile:(const char *)_path Uid:(uid_t)_uid Gid:(gid_t)_gid
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:YES];

    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Chown Error"];
    [alert SetInformativeText:
        [NSString stringWithFormat:@"Can't change owner and/or group.\nError: %s\nFile: %@",
         strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnFileTimeError:(int)_error ForFile:(const char *)_path WithAttr:(u_int32_t)_attr Time:(timespec)_time
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:YES];
    
    const char *time_string = "(error)";
    switch (_attr) {
        case ATTR_CMN_ACCTIME: time_string = "access"; break;
        case ATTR_CMN_MODTIME: time_string = "modify"; break;
        case ATTR_CMN_CHGTIME: time_string = "change"; break;
        case ATTR_CMN_CRTIME: time_string = "create"; break;
    }
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Set file time error"];
    [alert SetInformativeText:
     [NSString stringWithFormat:@"Can't set %s time\nError: %s\nFile: %@",
      time_string, strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnOpendirError:(int)_error ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:YES];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Directory access error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nDirectory: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnStatError:(int)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:YES];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Can't get file status"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
