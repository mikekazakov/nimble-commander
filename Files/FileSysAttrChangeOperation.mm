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

@implementation FileSysAttrChangeOperation
{
    FileSysAttrChangeOperationJob m_Job;
}

- (id)initWithCommand:(shared_ptr<FileSysAttrAlterCommand>)_command
{
    self = [super initWithJob:&m_Job];
    if (self) {
        m_Job.Init(_command, self);
        
        // Set caption.
        if (_command->files.size() == 1) {
            self.Caption = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Altering attributes of \u201c%@\u201d",
                                                                                 @"Operations",
                                                                                 "Title of attributes change operation for single file"),
                            [NSString stringWithUTF8String:_command->files.front().c_str()]];
        }
        else {
            // Get directory name from path.
            char buff[MAXPATHLEN] = {0};
            GetDirectoryNameFromPath(_command->root_path.c_str(), buff, MAXPATHLEN);
            
            self.Caption = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Altering attributes of %@ items in \u201c%@\u201d",
                                                                                 @"Operations",
                                                                                 "Title of attributes change operation for multiple files"),
                            [NSNumber numberWithUnsignedLong:_command->files.size()],
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
    
    if (stats.IsCurrentItemChanged()) {
        auto item = stats.GetCurrentItem();
        if (item.empty())
            self.ShortInfo = @"";
        else
            self.ShortInfo = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Processing \u201c%@\u201d",
                                                                                   @"Operations",
                                                                                   "Operation short info"),
                              [NSString stringWithUTF8StdString:item]];
    }
}

- (OperationDialogAlert *)DialogOnChmodError:(int)_error
                                   ForFile:(const char *)_path
                                  WithMode:(mode_t)_mode
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:YES];
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to perform chmod",
                                                     @"Operations",
                                                     "Error dialog title on chmod failure")];
    char buff[12];
    strmode(_mode, buff);
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nFile: %@\nMode: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on chmod failure dialog"),
                               ErrnoToNSError(_error).localizedDescription,
                               [NSString stringWithUTF8String:_path],
                               [NSString stringWithUTF8String:buff]]
     ];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogOnChflagsError:(int)_error
                                     ForFile:(const char*)_path
                                   WithFlags:(uint32_t)_flags
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:YES];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to perform chflags",
                                                     @"Operations",
                                                     "Error dialog title on chflags failure")];
    char *str = fflagstostr(_flags);
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nFile: %@\nFlags: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on chflags failure dialog"),
                               ErrnoToNSError(_error).localizedDescription,
                               [NSString stringWithUTF8String:_path],
                               [NSString stringWithUTF8String:str]]
     ];
    free(str);
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogOnChownError:(int)_error ForFile:(const char *)_path Uid:(uid_t)_uid Gid:(gid_t)_gid
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:YES];
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to perform chown",
                                                     @"Operations",
                                                     "Error dialog title on chown failure")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nFile: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on chown failure dialog"),
         ErrnoToNSError(_error).localizedDescription,
         [NSString stringWithUTF8String:_path]]
     ];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogOnFileTimeError:(int)_error ForFile:(const char *)_path WithAttr:(u_int32_t)_attr Time:(timespec)_time
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:YES];
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to set file time",
                                                     @"Operations",
                                                     "Error dialog title on time setting failure")];
    NSString *fmt = @"";
    switch (_attr) {
        case ATTR_CMN_ACCTIME:fmt = NSLocalizedStringFromTable(@"Can’t set access time\nError: %@\nFile: %@",
                                                               @"Operations",
                                                               "Informative text to setting access time");
            break;
        case ATTR_CMN_MODTIME:fmt = NSLocalizedStringFromTable(@"Can’t set modification time\nError: %@\nFile: %@",
                                                               @"Operations",
                                                               "Informative text to setting modify time");
            break;
        case ATTR_CMN_CHGTIME:fmt = NSLocalizedStringFromTable(@"Can’t set change time\nError: %@\nFile: %@",
                                                               @"Operations",
                                                               "Informative text to setting change time");
            break;
        case ATTR_CMN_CRTIME:fmt = NSLocalizedStringFromTable(@"Can’t set creation time\nError: %@\nFile: %@",
                                                              @"Operations",
                                                              "Informative text to setting creation time");
            break;
    }
    
    [alert SetInformativeText:[NSString stringWithFormat:fmt,
                               ErrnoToNSError(_error).localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogOnOpendirError:(int)_error ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:YES];
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to access a directory",
                                                     @"Operations",
                                                     "Error dialog title on directory access failure")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nDirectory: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on directory access failure"),
                               ErrnoToNSError(_error).localizedDescription,
                               [NSString stringWithUTF8String:_path]]
     ];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogOnStatError:(int)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:YES];
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to access a file",
                                                     @"Operations",
                                                     "Error dialog title on file access failure")];
    
    
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nDirectory: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on file access failure"),
                               ErrnoToNSError(_error).localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
