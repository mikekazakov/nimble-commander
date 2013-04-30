//
//  FileCopyOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileCopyOperation.h"
#import "FileCopyOperationJob.h"
#import "Common.h"

@implementation FileCopyOperation
{
    FileCopyOperationJob m_Job;
    int m_LastInfoUpdateTime;
}

- (id)initWithFiles:(FlexChainedStringsChunk*)_files // passing with ownership, operation will free it on finish
               root:(const char*)_root
               dest:(const char*)_dest
            options:(FileCopyOperationOptions*)_opts
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_files, _root, _dest, _opts, self);
        
        // Set caption.
        char buff[128] = {0};
        GetDirectoryFromPath(_dest, buff, 128);
        if (_files->amount == 1)
        {
            self.Caption = [NSString stringWithFormat:@"Copying \"%@\" to \"%@\"",
                            [NSString stringWithUTF8String:_files->strings[0].str()],
                            [NSString stringWithUTF8String:buff]];
        }
        else
        {
            self.Caption = [NSString stringWithFormat:@"Copying %i items to \"%@\"",
                            _files->amount,
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
    
    FileCopyOperationJob::StatValueType value_type = m_Job.GetStatValueType();
    bool item_changed = stats.IsCurrentItemChanged();
    if (value_type == FileCopyOperationJob::StatValueUnknown
        || (!item_changed && (m_Job.IsPaused() || self.DialogsCount)))
    {
        return;
    }
    
    int time = stats.GetTime();
    if (time - m_LastInfoUpdateTime >= 1000 || item_changed)
    {
        if (value_type == FileCopyOperationJob::StatValueBytes)
        {
            double mbytes = stats.GetValue()/1000000.0;
            double mbytes_total = stats.GetMaxValue()/1000000.0;
            double mbytes_left = mbytes_total - mbytes;
            double mbytes_per_sec = time ? mbytes/time*1000.0 : 0;
            int eta_in_sec = time ? int(mbytes_left/mbytes_per_sec) : 0;
            self.ShortInfo = [NSString stringWithFormat:
                              @"%.1f MB of %.1f MB - %.1f MB/s - eta %i sec",
                              mbytes, mbytes_total, mbytes_per_sec, eta_in_sec];
        }
        else if (value_type == FileCopyOperationJob::StatValueFiles)
        {
            const char *file = stats.GetCurrentItem();
            if (!file)
            {
                self.ShortInfo = @"";
            }
            else
            {
                self.ShortInfo = [NSString stringWithFormat:@"Processing \"%@\"",
                                  [NSString stringWithUTF8String:file]];
            }
        
        }
        else assert(0); // sanity check
        
        m_LastInfoUpdateTime = time;
    }
}

- (OperationDialogAlert *)OnDestCantCreateDir:(int)_error ForDir:(const char *)_path
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

- (OperationDialogAlert *)OnCopyCantCreateDir:(int)_error ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_Job.IsSingleFileCopy()];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to create directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];

    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantAccessSrcFile:(int)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_Job.IsSingleFileCopy()];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to access file"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantOpenDestFile:(int)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_Job.IsSingleFileCopy()];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to open file"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyReadError:(int)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_Job.IsSingleFileCopy()];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Read error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyWriteError:(int)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_Job.IsSingleFileCopy()];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Write error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (FileAlreadyExistSheetController *)OnFileExist: (const char*)_path
                                         newsize: (unsigned long)_newsize
                                         newtime: (time_t) _newtime
                                         exisize: (unsigned long)_exisize
                                         exitime: (time_t) _exitime
                                        remember: (bool*)  _remb
{
    FileAlreadyExistSheetController *sheet = [[FileAlreadyExistSheetController alloc]
                                              initWithFile:_path
                                              newsize:_newsize
                                              newtime:_newtime
                                              exisize:_exisize
                                              exitime:_exitime
                                              remember:_remb
                                              single:m_Job.IsSingleFileCopy()];

    [self EnqueueDialog:sheet];
    return sheet;
}

- (OperationDialogAlert *)OnRenameDestinationExists:(const char *)_dest
                                             Source:(const char *)_src
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    [alert AddButtonWithTitle:@"Rewrite" andResult:OperationDialogResult::Continue];
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Destination already exists. Do you want to rewrite it?"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Destination: %@\nSource: %@",
                               [NSString stringWithUTF8String:_dest],
                               [NSString stringWithUTF8String:_src]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
