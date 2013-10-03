//
//  FileCopyOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileCopyOperation.h"
#import "FileCopyOperationJob.h"
#import "FileCopyOperationJobFromGeneric.h"
#import "Common.h"

static void FormHumanReadableTimeRepresentation(uint64_t _time, char _out[18])
{
    if(_time < 60) // seconds
    {
        sprintf(_out, "%llu s", _time);
    }
    else if(_time < 60*60) // minutes
    {
        sprintf(_out, "%llu min", (_time + 30)/60);
    }
    else if(_time < 24*3600lu) // hours
    {
        sprintf(_out, "%llu h", (_time + 1800)/3600);
    }
    else if(_time < 31*86400lu) // days
    {
        sprintf(_out, "%llu d", (_time + 43200)/86400lu);
    }
}

static void FormHumanReadableSizeRepresentation(uint64_t _sz, char _out[18])
{    
    if(_sz < 1024) // bytes
    {
        sprintf(_out, "%3llu", _sz);
    }
    else if(_sz < 1024lu * 1024lu) // kilobytes
    {
        double size = _sz/1024.0;
        sprintf(_out, "%.1f KB", size);
    }
    else if(_sz < 1024lu * 1048576lu) // megabytes
    {
        double size = (_sz/1024)/1024.0;
        sprintf(_out, "%.1fMB", size);
    }
    else if(_sz < 1024lu * 1073741824lu) // gigabytes
    {
        double size = (_sz/1048576lu)/1024.0;
        sprintf(_out, "%.1fGB", size);
    }
    else if(_sz < 1024lu * 1099511627776lu) // terabytes
    {
        double size = (_sz/1073741824lu)/1024.0;
        sprintf(_out, "%.1f TB", size);
    }
    else if(_sz < 1024lu * 1125899906842624lu) // petabytes
    {
        double size = (_sz/1099511627776lu)/1024.0;
        sprintf(_out, "%.1f PB", size);
    }
}

@implementation FileCopyOperation
{
//    FileCopyOperationJob m_Job;
    std::shared_ptr<FileCopyOperationJob> m_NativeToNativeJob;
    std::shared_ptr<FileCopyOperationJobFromGeneric> m_GenericToNativeJob;
    
    
    int m_LastInfoUpdateTime;
}

- (id)initWithFiles:(FlexChainedStringsChunk*)_files // passing with ownership, operation will free it on finish
               root:(const char*)_root
               dest:(const char*)_dest
            options:(FileCopyOperationOptions*)_opts
{
    m_NativeToNativeJob = std::make_shared<FileCopyOperationJob>();
    self = [super initWithJob:m_NativeToNativeJob.get()];
    if (self)
    {
        m_NativeToNativeJob->Init(_files, _root, _dest, _opts, self);
        
        // Set caption.
        char buff[128] = {0};
        bool use_buff = GetDirectoryFromPath(_dest, buff, 128);
        int items_amount = _files->CountStringsWithDescendants();
        
        // TODO: copy/rename title difference
        if (items_amount == 1)
        {
            self.Caption = [NSString stringWithFormat:@"Copying \"%@\" to \"%@\"",
                            [NSString stringWithUTF8String:(*_files)[0].str()],
                            [NSString stringWithUTF8String:(use_buff ? buff : _dest)]];
        }
        else
        {
            self.Caption = [NSString stringWithFormat:@"Copying %i items to \"%@\"",
                            items_amount,
                            [NSString stringWithUTF8String:(use_buff ? buff : _dest)]];
        }
    }
    return self;
}

- (id)initWithFiles:(FlexChainedStringsChunk*)_files // passing with ownership, operation will free it on finish
               root:(const char*)_root
            rootvfs:(std::shared_ptr<VFSHost>)_vfs
               dest:(const char*)_dest
            options:(FileCopyOperationOptions*)_opts
{
    m_GenericToNativeJob = std::make_shared<FileCopyOperationJobFromGeneric>();
    self = [super initWithJob:m_GenericToNativeJob.get()];
    if (self)
    {
        m_GenericToNativeJob->Init(_files, _root, _vfs, _dest, _opts, self);

        // other stuff here
    }
    return self;
}


- (void)Update
{
    if(m_NativeToNativeJob.get())
        [self UpdateNativeToNative];
    if(m_GenericToNativeJob.get())
        [self UpdateGenericToNative];
}

- (void)UpdateNativeToNative
{
    OperationStats &stats = m_NativeToNativeJob->GetStats();
    float progress = stats.GetProgress();
    if (self.Progress != progress)
        self.Progress = progress;
    
    FileCopyOperationJob::StatValueType value_type = m_NativeToNativeJob->GetStatValueType();
    if (value_type == FileCopyOperationJob::StatValueUnknown || m_NativeToNativeJob->IsPaused()
        || self.DialogsCount)
    {
        return;
    }
    
    int time = stats.GetTime();
    if (time - m_LastInfoUpdateTime >= 1000)
    {
        if (value_type == FileCopyOperationJob::StatValueBytes)
        {
            uint64_t copy_speed = 0;
            if (time) copy_speed = stats.GetValue()*1000/time;
            uint64_t eta_value = 0;
            if (copy_speed) eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
            
            char copied[18] = {0}, total[18] = {0}, speed[18] = {0}, eta[18] = {0};
            FormHumanReadableSizeRepresentation(stats.GetValue(), copied);
            FormHumanReadableSizeRepresentation(stats.GetMaxValue(), total);
            FormHumanReadableSizeRepresentation(copy_speed, speed);
            if (copy_speed)
                FormHumanReadableTimeRepresentation(eta_value, eta);
            
            if (copy_speed)
            {
                self.ShortInfo = [NSString stringWithFormat:@"%s of %s - %s/s - %s",
                                  copied, total, speed, eta];
            }
            else
            {
                self.ShortInfo = [NSString stringWithFormat:@"%s of %s - %s/s",
                                  copied, total, speed];
            }
        }
        else if (stats.IsCurrentItemChanged() && value_type == FileCopyOperationJob::StatValueFiles)
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

- (void)UpdateGenericToNative
{
    OperationStats &stats = m_GenericToNativeJob->GetStats();
    float progress = stats.GetProgress();
    if (self.Progress != progress)
        self.Progress = progress;
    
    if (m_GenericToNativeJob->IsPaused() || self.DialogsCount)
    {
        return;
    }
    
    int time = stats.GetTime();
    if (time - m_LastInfoUpdateTime >= 1000)
    {
        uint64_t copy_speed = 0;
        if (time) copy_speed = stats.GetValue()*1000/time;
        uint64_t eta_value = 0;
        if (copy_speed) eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
            
        char copied[18] = {0}, total[18] = {0}, speed[18] = {0}, eta[18] = {0};
        FormHumanReadableSizeRepresentation(stats.GetValue(), copied);
        FormHumanReadableSizeRepresentation(stats.GetMaxValue(), total);
        FormHumanReadableSizeRepresentation(copy_speed, speed);
        if (copy_speed)
            FormHumanReadableTimeRepresentation(eta_value, eta);
            
        if (copy_speed)
        {
            self.ShortInfo = [NSString stringWithFormat:@"%s of %s - %s/s - %s",
                                copied, total, speed, eta];
        }
        else
        {
            self.ShortInfo = [NSString stringWithFormat:@"%s of %s - %s/s",
                                copied, total, speed];
        }
        
        m_LastInfoUpdateTime = time;
    }
}

- (bool) IsSingleFileCopy
{
    if(!m_NativeToNativeJob.get()) return false;
    return m_NativeToNativeJob->IsSingleFileCopy();
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
                                   initRetrySkipSkipAllAbortHide:![self IsSingleFileCopy]];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to create directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];

    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantAccessSrcFile:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:![self IsSingleFileCopy]];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to access file"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nPath: %@",
                               [_error localizedDescription],
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantOpenDestFile:(int)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:![self IsSingleFileCopy]];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to open file"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyReadError:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:![self IsSingleFileCopy]];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Read error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nPath: %@",
                               [_error localizedDescription],
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyWriteError:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:![self IsSingleFileCopy]];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Write error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nPath: %@",
                               [_error localizedDescription],
                               [NSString stringWithUTF8String:_path]]];
    
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
                                              single:[self IsSingleFileCopy]];

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
