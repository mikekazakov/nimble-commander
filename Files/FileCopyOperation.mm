//
//  FileCopyOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileCopyOperation.h"
#import "FileCopyOperationJobNativeToNative.h"
#import "FileCopyOperationJobFromGeneric.h"
#import "FileCopyOperationJobGenericToGeneric.h"
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
    unique_ptr<FileCopyOperationJobNativeToNative> m_NativeToNativeJob;
    unique_ptr<FileCopyOperationJobFromGeneric> m_GenericToNativeJob;
    unique_ptr<FileCopyOperationJobGenericToGeneric> m_GenericToGenericJob;
    
    
    int m_LastInfoUpdateTime;
}

- (id)initWithFiles:(chained_strings)_files
               root:(const char*)_root
               dest:(const char*)_dest
            options:(FileCopyOperationOptions*)_opts
{
    m_NativeToNativeJob = make_unique<FileCopyOperationJobNativeToNative>();
    self = [super initWithJob:m_NativeToNativeJob.get()];
    if (self)
    {
        // Set caption.
        char buff[128] = {0};
        bool use_buff = GetDirectoryFromPath(_dest, buff, 128);
        int items_amount = _files.size();
        
        NSString *operation = _opts->docopy ? @"Copying" : @"Moving";
        if (items_amount == 1)
            self.Caption = [NSString stringWithFormat:@"%@ \"%@\" to \"%@\"",
                            operation,
                            [NSString stringWithUTF8String:_files.front().c_str()],
                            [NSString stringWithUTF8String:(use_buff ? buff : _dest)]];
        else
            self.Caption = [NSString stringWithFormat:@"Copying %i items to \"%@\"",
                            items_amount,
                            [NSString stringWithUTF8String:(use_buff ? buff : _dest)]];

        m_NativeToNativeJob->Init(move(_files), _root, _dest, _opts, self);
    }
    return self;
}

- (id)initWithFiles:(chained_strings)_files
               root:(const char*)_root
            rootvfs:(shared_ptr<VFSHost>)_vfs
               dest:(const char*)_dest
            options:(FileCopyOperationOptions*)_opts
{
    m_GenericToNativeJob = make_unique<FileCopyOperationJobFromGeneric>();
    self = [super initWithJob:m_GenericToNativeJob.get()];
    if (self)
    {
        // Set caption.
        char buff[128] = {0};
        bool use_buff = GetDirectoryFromPath(_dest, buff, 128);
        int items_amount = _files.size();
        
        NSString *operation = _opts->docopy ? @"Copying" : @"Moving";
        if (items_amount == 1)
            self.Caption = [NSString stringWithFormat:@"%@ \"%@\" to \"%@\"",
                            operation,
                            [NSString stringWithUTF8String:_files.front().c_str()],
                            [NSString stringWithUTF8String:(use_buff ? buff : _dest)]];
        else
            self.Caption = [NSString stringWithFormat:@"%@ %i items to \"%@\"",
                            operation,
                            items_amount,
                            [NSString stringWithUTF8String:(use_buff ? buff : _dest)]];
        
        m_GenericToNativeJob->Init(move(_files), _root, _vfs, _dest, _opts, self);
    }
    return self;
}

- (id)initWithFiles:(chained_strings)_files
               root:(const char*)_root
             srcvfs:(shared_ptr<VFSHost>)_vfs
               dest:(const char*)_dest
             stdvfs:(shared_ptr<VFSHost>)_dst_vfs
            options:(FileCopyOperationOptions*)_opts
{
    m_GenericToGenericJob = make_unique<FileCopyOperationJobGenericToGeneric>();
    self = [super initWithJob:m_GenericToGenericJob.get()];
    if (self)
    {
        m_GenericToGenericJob->Init(move(_files),
                                    _root,
                                    _vfs,
                                    _dest,
                                    _dst_vfs,
                                    _opts,
                                    self);
    
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
    
    FileCopyOperationJobNativeToNative::StatValueType value_type = m_NativeToNativeJob->GetStatValueType();
    if (value_type == FileCopyOperationJobNativeToNative::StatValueUnknown || m_NativeToNativeJob->IsPaused()
        || self.DialogsCount)
    {
        return;
    }
    
    int time = stats.GetTime();
    if (time - m_LastInfoUpdateTime >= 1000)
    {
        if (value_type == FileCopyOperationJobNativeToNative::StatValueBytes)
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
        else if (stats.IsCurrentItemChanged() && value_type == FileCopyOperationJobNativeToNative::StatValueFiles)
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
