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
#import "ByteCountFormatter.h"

static void FormHumanReadableTimeRepresentation(uint64_t _time, char _out[18])
{
    // TODO: localize!
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

static NSString *OpTitlePreffix(bool _copying)
{
    return _copying ?
        NSLocalizedStringFromTable(@"Copying", @"Operations", "Operation title prefix for copying") :
        NSLocalizedStringFromTable(@"Moving", @"Operations", "Operaration title prefix for moving");;
}

static NSString *OpTitleForSingleItem(bool _copying, NSString *_item, NSString *_to)
{
    return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ \u201c%@\u201d to \u201c%@\u201d", @"Operations", "Title for copying or moving a single item"),
            OpTitlePreffix(_copying),
            _item,
            _to];
}

static NSString *OpTitleForMultipleItems(bool _copying, int _items, NSString *_to)
{
    return [NSString stringWithFormat:NSLocalizedStringFromTable(@"%@ %@ items to \u201c%@\u201d", @"Operations", "Title for copying or moving a multiple items"),
            OpTitlePreffix(_copying),
            [NSNumber numberWithInt:_items],
            _to];
}

@implementation FileCopyOperation
{
    unique_ptr<FileCopyOperationJobNativeToNative> m_NativeToNativeJob;
    unique_ptr<FileCopyOperationJobFromGeneric> m_GenericToNativeJob;
    unique_ptr<FileCopyOperationJobGenericToGeneric> m_GenericToGenericJob;
    milliseconds m_LastInfoUpdateTime;
}

- (id)initWithFiles:(vector<string>)_files
               root:(const char*)_root
               dest:(const char*)_dest
            options:(const FileCopyOperationOptions&)_opts
{
    m_NativeToNativeJob = make_unique<FileCopyOperationJobNativeToNative>();
    self = [super initWithJob:m_NativeToNativeJob.get()];
    if (self)
    {
        // Set caption.
        char buff[MAXPATHLEN] = {0};
        bool use_buff = GetDirectoryNameFromPath(_dest, buff, MAXPATHLEN);
        NSString *to = [NSString stringWithUTF8String:(use_buff ? buff : _dest)];
        if ( _files.size() == 1)
            self.Caption = OpTitleForSingleItem(_opts.docopy, [NSString stringWithUTF8String:_files.front().c_str()], to);
        else
            self.Caption = OpTitleForMultipleItems(_opts.docopy, (int)_files.size(), to);
        
        m_NativeToNativeJob->Init(move(_files), _root, _dest, _opts, self);
    }
    return self;
}

- (id)initWithFiles:(vector<string>)_files
               root:(const char*)_root
            rootvfs:(shared_ptr<VFSHost>)_vfs
               dest:(const char*)_dest
            options:(const FileCopyOperationOptions&)_opts
{
    m_GenericToNativeJob = make_unique<FileCopyOperationJobFromGeneric>();
    self = [super initWithJob:m_GenericToNativeJob.get()];
    if (self)
    {
        // Set caption.
        char buff[MAXPATHLEN] = {0};
        bool use_buff = GetDirectoryNameFromPath(_dest, buff, MAXPATHLEN);
        int items_amount = (int)_files.size();
        NSString *to = [NSString stringWithUTF8String:(use_buff ? buff : _dest)];
        if (items_amount == 1)
            self.Caption = OpTitleForSingleItem(_opts.docopy, [NSString stringWithUTF8String:_files.front().c_str()], to);
        else
            self.Caption = OpTitleForMultipleItems(_opts.docopy, items_amount, to);
        
        m_GenericToNativeJob->Init(move(_files), _root, _vfs, _dest, _opts, self);
    }
    return self;
}

- (id)initWithFiles:(vector<string>)_files
               root:(const char*)_root
             srcvfs:(shared_ptr<VFSHost>)_vfs
               dest:(const char*)_dest
             dstvfs:(shared_ptr<VFSHost>)_dst_vfs
            options:(const FileCopyOperationOptions&)_opts
{
    m_GenericToGenericJob = make_unique<FileCopyOperationJobGenericToGeneric>();
    self = [super initWithJob:m_GenericToGenericJob.get()];
    if (self)
    {
        // Set caption.
        char buff[MAXPATHLEN] = {0};
        bool use_buff = GetDirectoryNameFromPath(_dest, buff, MAXPATHLEN);
        int items_amount = (int)_files.size();
        NSString *to = [NSString stringWithUTF8String:(use_buff ? buff : _dest)];
        if (items_amount == 1)
            self.Caption = OpTitleForSingleItem(_opts.docopy, [NSString stringWithUTF8String:_files.front().c_str()], to);
        else
            self.Caption = OpTitleForMultipleItems(_opts.docopy, items_amount, to);
        
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
    if(m_NativeToNativeJob)
        [self UpdateNativeToNative];
    if(m_GenericToNativeJob)
        [self UpdateGenericToNative];
    if(m_GenericToGenericJob)
        [self UpdateGenericToGeneric];
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
    
    milliseconds time = stats.GetTime();
    if (time - m_LastInfoUpdateTime >= 1000ms)
    {
        if (value_type == FileCopyOperationJobNativeToNative::StatValueBytes)
        {
            uint64_t copy_speed = 0;
            if (time.count()>0) copy_speed = stats.GetValue()*1000/time.count();
            uint64_t eta_value = 0;
            if (copy_speed) eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
            
            char eta[18] = {0};

            if (copy_speed)
                FormHumanReadableTimeRepresentation(eta_value, eta);

            auto &f = ByteCountFormatter::Instance();
            if (copy_speed)
                self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s - %s",
                                  f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
                                  f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
                                  f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6),
                                  eta];
            else
                self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s",
                                  f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
                                  f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
                                  f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6)];
        }
        else if (stats.IsCurrentItemChanged() && value_type == FileCopyOperationJobNativeToNative::StatValueFiles)
        {
            auto file = stats.GetCurrentItem();
            if (file.empty())
                self.ShortInfo = @"";
            else
                self.ShortInfo = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Processing \u201c%@\u201d",
                                                                                       @"Operations",
                                                                                       "Title for processing a single item"),
                                  [NSString stringWithUTF8StdString:file]];
        }
        
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
    
    milliseconds time = stats.GetTime();
    if (time - m_LastInfoUpdateTime >= 1000ms)
    {
        uint64_t copy_speed = 0;
        if (time.count() > 0) copy_speed = stats.GetValue()*1000/time.count();
        uint64_t eta_value = 0;
        if (copy_speed) eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
            
        char eta[18] = {0};
        if (copy_speed)
            FormHumanReadableTimeRepresentation(eta_value, eta);

        // TODO: localize!
        auto &f = ByteCountFormatter::Instance();
        if (copy_speed)
            self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s - %s",
                              f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
                              f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
                              f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6),
                              eta];
        else
            self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s",
                              f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
                              f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
                              f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6)];
        
        m_LastInfoUpdateTime = time;
    }
}

- (void)UpdateGenericToGeneric
{
    OperationStats &stats = m_GenericToGenericJob->GetStats();
    float progress = stats.GetProgress();
    if (self.Progress != progress)
        self.Progress = progress;
    
    if (m_GenericToGenericJob->IsPaused() || self.DialogsCount)
    {
        return;
    }
    
    milliseconds time = stats.GetTime();
    if (time - m_LastInfoUpdateTime >= 1000ms)
    {
        uint64_t copy_speed = 0;
        if (time.count()>0) copy_speed = stats.GetValue()*1000/time.count();
        uint64_t eta_value = 0;
        if (copy_speed) eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
        
        char eta[18] = {0};
        if (copy_speed)
            FormHumanReadableTimeRepresentation(eta_value, eta);
        
        // TODO: localize!
        auto &f = ByteCountFormatter::Instance();
        if (copy_speed)
            self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s - %s",
                              f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
                              f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
                              f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6),
                              eta];
        else
            self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s",
                              f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
                              f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
                              f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6)];
        
        m_LastInfoUpdateTime = time;
    }
}

- (bool) IsSingleFileCopy
{
    if(!m_NativeToNativeJob) return false;
    return m_NativeToNativeJob->IsSingleFileCopy();
}

- (NSString*) buildInformativeStringForError:(NSError*)_error onPath:(const char *)_path
{
    return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nPath: %@", @"Operations", "Error informative text with path"),
            _error.localizedDescription,
            [NSString stringWithUTF8String:_path]];
}

- (OperationDialogAlert *)OnCantCreateDir:(NSError*)_error ForDir:(const char *)_path;
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:NO];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to create directory", @"Operations", "Error sheet prompt on dir creation")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantAccessSrcFile:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:![self IsSingleFileCopy]];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to access a file", @"Operations", "Title on error when source file is inaccessible")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantOpenDestFile:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:![self IsSingleFileCopy]];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to open destination file", @"Operations", "Title on error when destination file can't be opened")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyReadError:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:![self IsSingleFileCopy]];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to read a file", @"Operations", "Error when reading failed")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyWriteError:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:![self IsSingleFileCopy]];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to write a file", @"Operations", "Error when writing failed")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    
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
    // TODO:
    // why we use here a different dialog, not one that used on copy operation?
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Rewrite", @"Operations", "User action button title to rewrite a file")
                    andResult:OperationDialogResult::Continue];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Abort", @"Operations", "User action button title to abort an operation")
                    andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Hide", @"Operations", "User action button title to hide an error sheet")
                    andResult:OperationDialogResult::None];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Destination already exists. Do you want to rewrite it?",
                                                     @"Operations",
                                                     "Title for error wheen when destination file already exists")];
    
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Destination: %@\nSource: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on case when destination file already exists"),
                               [NSString stringWithUTF8String:_dest],
                               [NSString stringWithUTF8String:_src]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
