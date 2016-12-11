//
//  FileCopyOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Utility/PathManip.h>
#include "FileCopyOperation.h"
#include "Job.h"
#include <Utility/ByteCountFormatter.h>
#include <NimbleCommander/Operations/OperationDialogAlert.h>
#include "FileAlreadyExistSheetController.h"
#include "DialogResults.h"

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

static NSString *ExtractCopyToName(const string&_s)
{
    char buff[MAXPATHLEN] = {0};
    bool use_buff = GetDirectoryNameFromPath(_s.c_str(), buff, MAXPATHLEN);
    NSString *to = [NSString stringWithUTF8String:(use_buff ? buff : _s.c_str())];
    return to;
}

@implementation FileCopyOperation
{
    FileCopyOperationJob m_Job;
}

- (id)initWithItems:(vector<VFSListingItem>)_files
    destinationPath:(const string&)_path
    destinationHost:(const VFSHostPtr&)_host
            options:(const FileCopyOperationOptions&)_options
{
    self = [super initWithJob:&m_Job];
    if (self) {
        // Set caption.
        if ( _files.size() == 1)
            self.Caption = OpTitleForSingleItem(_options.docopy,
                                                [NSString stringWithUTF8StdString:_files.front().Filename()],
                                                ExtractCopyToName(_path));
        else
            self.Caption = OpTitleForMultipleItems(_options.docopy,
                                                   (int)_files.size(),
                                                   ExtractCopyToName(_path));
        
        
        m_Job.Init(move(_files), _path, _host, _options);
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
        __weak auto weak_self = self;
        m_Job.GetStats().RegisterObserver(OperationStats::Nofity::Value,
                                          nullptr,
                                          [weak_self]{ if(auto me = weak_self) [me updateOnProgressChanged]; }
                                          );
        m_Job.GetStats().RegisterObserver(OperationStats::Nofity::Value,
                                          nullptr,
                                          [weak_self]{ if(auto me = weak_self) [me updateOnProgressChangedSlow]; },
                                          true,
                                          500ms
                                          );
        m_Job.GetStats().RegisterObserver(OperationStats::Nofity::CurrentItem,
                                          nullptr,
                                          [weak_self]{ if(auto me = weak_self) [me updateOnItemChanged]; }
                                          );
        m_Job.RegisterObserver(FileCopyOperationJob::Notify::Stage,
                               nullptr,
                               [weak_self]{ if(auto me = weak_self) [me updateOnStageChanged]; }
                               );
#pragma diagnostic pop
        
        [self setupDialogs];
    }
    return self;
}

+ (instancetype) singleItemRenameOperation:(VFSListingItem)_item
                                   newName:(const string&)_filename
{
    FileCopyOperationOptions opts;
    opts.docopy = false;
    return [[FileCopyOperation alloc] initWithItems:{_item}
                                    destinationPath:_item.Directory() + _filename
                                    destinationHost:_item.Host()
                                            options:opts];
}



//- (id)initWithFiles:(vector<string>)_files
//               root:(const char*)_root
//               dest:(const char*)_dest
//            options:(const FileCopyOperationOptions&)_opts
//{
//    m_NativeToNativeJob = make_unique<FileCopyOperationJobNativeToNative>();
//    self = [super initWithJob:m_NativeToNativeJob.get()];
//    if (self)
//    {
//        // Set caption.
//        char buff[MAXPATHLEN] = {0};
//        bool use_buff = GetDirectoryNameFromPath(_dest, buff, MAXPATHLEN);
//        NSString *to = [NSString stringWithUTF8String:(use_buff ? buff : _dest)];
//        if ( _files.size() == 1)
//            self.Caption = OpTitleForSingleItem(_opts.docopy, [NSString stringWithUTF8String:_files.front().c_str()], to);
//        else
//            self.Caption = OpTitleForMultipleItems(_opts.docopy, (int)_files.size(), to);
//        
//        m_NativeToNativeJob->Init(move(_files), _root, _dest, _opts, self);
//        
//        __weak FileCopyOperation* wself = self;
//        self.Stats.SetOnCurrentItemChanged([wself]{
//            if(FileCopyOperation* sself = wself)
//                [sself Update];
//        });
//    }
//    return self;
//}
//
//- (id)initWithFiles:(vector<string>)_files
//               root:(const char*)_root
//            rootvfs:(shared_ptr<VFSHost>)_vfs
//               dest:(const char*)_dest
//            options:(const FileCopyOperationOptions&)_opts
//{
//    m_GenericToNativeJob = make_unique<FileCopyOperationJobFromGeneric>();
//    self = [super initWithJob:m_GenericToNativeJob.get()];
//    if (self)
//    {
//        // Set caption.
//        char buff[MAXPATHLEN] = {0};
//        bool use_buff = GetDirectoryNameFromPath(_dest, buff, MAXPATHLEN);
//        int items_amount = (int)_files.size();
//        NSString *to = [NSString stringWithUTF8String:(use_buff ? buff : _dest)];
//        if (items_amount == 1)
//            self.Caption = OpTitleForSingleItem(_opts.docopy, [NSString stringWithUTF8String:_files.front().c_str()], to);
//        else
//            self.Caption = OpTitleForMultipleItems(_opts.docopy, items_amount, to);
//        
//        m_GenericToNativeJob->Init(move(_files), _root, _vfs, _dest, _opts, self);
//    }
//    return self;
//}
//
//- (id)initWithFiles:(vector<string>)_files
//               root:(const char*)_root
//             srcvfs:(shared_ptr<VFSHost>)_vfs
//               dest:(const char*)_dest
//             dstvfs:(shared_ptr<VFSHost>)_dst_vfs
//            options:(const FileCopyOperationOptions&)_opts
//{
//    m_GenericToGenericJob = make_unique<FileCopyOperationJobGenericToGeneric>();
//    self = [super initWithJob:m_GenericToGenericJob.get()];
//    if (self)
//    {
//        // Set caption.
//        char buff[MAXPATHLEN] = {0};
//        bool use_buff = GetDirectoryNameFromPath(_dest, buff, MAXPATHLEN);
//        int items_amount = (int)_files.size();
//        NSString *to = [NSString stringWithUTF8String:(use_buff ? buff : _dest)];
//        if (items_amount == 1)
//            self.Caption = OpTitleForSingleItem(_opts.docopy, [NSString stringWithUTF8String:_files.front().c_str()], to);
//        else
//            self.Caption = OpTitleForMultipleItems(_opts.docopy, items_amount, to);
//        
//        m_GenericToGenericJob->Init(move(_files),
//                                    _root,
//                                    _vfs,
//                                    _dest,
//                                    _dst_vfs,
//                                    _opts,
//                                    self);
//    }
//    return self;
//}

- (void)updateOnStageChanged
{
    if( m_Job.Stage() == FileCopyOperationJob::JobStage::Cleaning )
        self.ShortInfo = NSLocalizedStringFromTable(@"Cleaning up",
                                                    @"Operations",
                                                    "ShortInfo text for file copy operation when it's cleaning source files");
}

- (void)updateOnItemChanged
{
    if( m_Job.Stage() == FileCopyOperationJob::JobStage::Verify )
        self.ShortInfo = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Verifying \u201c%@\u201d",
                                                                               @"Operations",
                                                                               "ShortInfo text for file copy operation when veryfying a copy result"),
                          [NSString stringWithUTF8StdString:*self.Stats.GetCurrentItem()]
                          ];
}

- (void)updateOnProgressChanged
{
    auto progress = m_Job.GetStats().GetProgress();
    if( self.Progress != progress )
        self.Progress = progress;
}

- (void)updateOnProgressChangedSlow
{
    auto &stats = m_Job.GetStats();
    
    auto time = stats.GetTime();
    uint64_t copy_speed = time.count() > 0 ? stats.GetValue()*1000/time.count() : 0;
    
    auto &f = ByteCountFormatter::Instance();
    if (copy_speed) {
        uint64_t eta_value =  stats.RemainingValue() / copy_speed;
        char eta[18] = {0};
        FormHumanReadableTimeRepresentation(eta_value, eta);
        self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s - %s",
                          f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
                          f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
                          f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6),
                          eta];
    }
    else
        self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s",
                          f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
                          f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
                          f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6)];
}

- (void)Update
{
//    auto abra = __COUNTER__;
    
//    auto &stats = m_Job.GetStats();
//    auto progress = m_Job.GetStats().GetProgress();
//    if( self.Progress != progress )
//        self.Progress = progress;
//    
//    auto time = stats.GetTime();
//    uint64_t copy_speed = time.count() > 0 ? stats.GetValue()*1000/time.count() : 0;
//
//    auto &f = ByteCountFormatter::Instance();
//    if (copy_speed) {
//        uint64_t eta_value =  stats.RemainingValue() / copy_speed;
//        char eta[18] = {0};
//        FormHumanReadableTimeRepresentation(eta_value, eta);
//        self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s - %s",
//                          f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
//                          f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
//                          f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6),
//                          eta];
//    }
//    else
//        self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s",
//                          f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
//                          f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
//                          f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6)];
    
    
    
    
//    if(m_NativeToNativeJob)
//        [self UpdateNativeToNative];
//    if(m_GenericToNativeJob)
//        [self UpdateGenericToNative];
//    if(m_GenericToGenericJob)
//        [self UpdateGenericToGeneric];
}

//- (void)UpdateNativeToNative
//{
//    OperationStats &stats = m_NativeToNativeJob->GetStats();
//    float progress = stats.GetProgress();
//    if (self.Progress != progress)
//        self.Progress = progress;
//    
//    FileCopyOperationJobNativeToNative::StatValueType value_type = m_NativeToNativeJob->GetStatValueType();
//    if (value_type == FileCopyOperationJobNativeToNative::StatValueUnknown || m_NativeToNativeJob->IsPaused()
//        || self.DialogsCount)
//    {
//        return;
//    }
//    
//    milliseconds time = stats.GetTime();
//    if (time - m_LastInfoUpdateTime >= 1000ms)
//    {
//        if (value_type == FileCopyOperationJobNativeToNative::StatValueBytes)
//        {
//            uint64_t copy_speed = 0;
//            if (time.count()>0) copy_speed = stats.GetValue()*1000/time.count();
//            uint64_t eta_value = 0;
//            if (copy_speed) eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
//            
//            char eta[18] = {0};
//
//            if (copy_speed)
//                FormHumanReadableTimeRepresentation(eta_value, eta);
//
//            auto &f = ByteCountFormatter::Instance();
//            if (copy_speed)
//                self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s - %s",
//                                  f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
//                                  f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
//                                  f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6),
//                                  eta];
//            else
//                self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s",
//                                  f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
//                                  f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
//                                  f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6)];
//        }
//        else if (value_type == FileCopyOperationJobNativeToNative::StatValueFiles)
//        {
//            auto file = stats.GetCurrentItem();
//            if (file->empty())
//                self.ShortInfo = @"";
//            else
//                self.ShortInfo = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Processing \u201c%@\u201d",
//                                                                                       @"Operations",
//                                                                                       "Title for processing a single item"),
//                                  [NSString stringWithUTF8StdString:*file]];
//        }
//        
//        m_LastInfoUpdateTime = time;
//    }
//}
//
//- (void)UpdateGenericToNative
//{
//    OperationStats &stats = m_GenericToNativeJob->GetStats();
//    float progress = stats.GetProgress();
//    if (self.Progress != progress)
//        self.Progress = progress;
//    
//    if (m_GenericToNativeJob->IsPaused() || self.DialogsCount)
//    {
//        return;
//    }
//    
//    milliseconds time = stats.GetTime();
//    if (time - m_LastInfoUpdateTime >= 1000ms)
//    {
//        uint64_t copy_speed = 0;
//        if (time.count() > 0) copy_speed = stats.GetValue()*1000/time.count();
//        uint64_t eta_value = 0;
//        if (copy_speed) eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
//            
//        char eta[18] = {0};
//        if (copy_speed)
//            FormHumanReadableTimeRepresentation(eta_value, eta);
//
//        // TODO: localize!
//        auto &f = ByteCountFormatter::Instance();
//        if (copy_speed)
//            self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s - %s",
//                              f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
//                              f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
//                              f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6),
//                              eta];
//        else
//            self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s",
//                              f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
//                              f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
//                              f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6)];
//        
//        m_LastInfoUpdateTime = time;
//    }
//}
//
//- (void)UpdateGenericToGeneric
//{
//    OperationStats &stats = m_GenericToGenericJob->GetStats();
//    float progress = stats.GetProgress();
//    if (self.Progress != progress)
//        self.Progress = progress;
//    
//    if (m_GenericToGenericJob->IsPaused() || self.DialogsCount)
//    {
//        return;
//    }
//    
//    milliseconds time = stats.GetTime();
//    if (time - m_LastInfoUpdateTime >= 1000ms)
//    {
//        uint64_t copy_speed = 0;
//        if (time.count()>0) copy_speed = stats.GetValue()*1000/time.count();
//        uint64_t eta_value = 0;
//        if (copy_speed) eta_value = (stats.GetMaxValue() - stats.GetValue())/copy_speed;
//        
//        char eta[18] = {0};
//        if (copy_speed)
//            FormHumanReadableTimeRepresentation(eta_value, eta);
//        
//        // TODO: localize!
//        auto &f = ByteCountFormatter::Instance();
//        if (copy_speed)
//            self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s - %s",
//                              f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
//                              f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
//                              f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6),
//                              eta];
//        else
//            self.ShortInfo = [NSString stringWithFormat:@"%@ of %@ - %@/s",
//                              f.ToNSString(stats.GetValue(), ByteCountFormatter::Adaptive6),
//                              f.ToNSString(stats.GetMaxValue(), ByteCountFormatter::Adaptive6),
//                              f.ToNSString(copy_speed, ByteCountFormatter::Adaptive6)];
//        
//        m_LastInfoUpdateTime = time;
//    }
//}

- (bool) isSingleFileCopy
{
    return m_Job.IsSingleScannedItemProcessing();
}

- (void) setupDialogs
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    __weak auto weak_self = self;
    m_Job.m_OnCopyDestinationAlreadyExists = [weak_self](const struct stat &_src_stat, const struct stat &_dst_stat, string _path){
        auto strong_self = weak_self; // what a wonderful dirty code!
        auto apply_to_all = make_shared<bool>(false);
        
        FileAlreadyExistSheetController *sheet = [[FileAlreadyExistSheetController alloc]
                                                  initWithDestPath:_path
                                                  withSourceStat:_src_stat
                                                  withDestinationStat:_dst_stat];
        sheet.singleItem = strong_self.isSingleFileCopy;
        sheet.applyToAll = apply_to_all;
        [strong_self EnqueueDialog:sheet];
        auto result = [sheet WaitForResult];
        
        if( *apply_to_all ) switch (result) {
                case FileCopyOperationDR::Skip:         strong_self->m_Job.ToggleExistBehaviorSkipAll();      break;
                case FileCopyOperationDR::Overwrite:    strong_self->m_Job.ToggleExistBehaviorOverwriteAll(); break;
                case FileCopyOperationDR::OverwriteOld: strong_self->m_Job.ToggleExistBehaviorOverwriteOld(); break;
                case FileCopyOperationDR::Append:       strong_self->m_Job.ToggleExistBehaviorAppendAll();    break;
            }
        return result;
    };
    m_Job.m_OnRenameDestinationAlreadyExists = [weak_self](const struct stat &_src_stat, const struct stat &_dst_stat, string _path){
        auto strong_self = weak_self; // what a wonderful dirty code!
        auto apply_to_all = make_shared<bool>(false);
        
        FileAlreadyExistSheetController *sheet = [[FileAlreadyExistSheetController alloc]
                                                  initWithDestPath:_path
                                                  withSourceStat:_src_stat
                                                  withDestinationStat:_dst_stat];
        sheet.singleItem = strong_self.isSingleFileCopy;
        sheet.allowAppending = false;
        sheet.applyToAll = apply_to_all;
        [strong_self EnqueueDialog:sheet];
        auto result = [sheet WaitForResult];
        
        if( *apply_to_all ) switch (result) {
            case FileCopyOperationDR::Skip:         strong_self->m_Job.ToggleExistBehaviorSkipAll();      break;
            case FileCopyOperationDR::Overwrite:    strong_self->m_Job.ToggleExistBehaviorOverwriteAll(); break;
            case FileCopyOperationDR::OverwriteOld: strong_self->m_Job.ToggleExistBehaviorOverwriteOld(); break;
        }
        return result;
    };
    m_Job.m_OnCantOpenDestinationFile = [weak_self](int _vfs_error, string _path){
        auto strong_self = weak_self;
        return [[strong_self OnCopyCantOpenDestFile:VFSError::ToNSError(_vfs_error) ForFile:_path.c_str()] WaitForResult];
    };
    m_Job.m_OnSourceFileReadError = [weak_self](int _vfs_error, string _path){
        auto strong_self = weak_self;
        return [[strong_self OnCopyReadError:VFSError::ToNSError(_vfs_error) ForFile:_path.c_str()] WaitForResult];
    };
    m_Job.m_OnDestinationFileWriteError = [weak_self](int _vfs_error, string _path){
        auto strong_self = weak_self;
        return [[strong_self OnCopyWriteError:VFSError::ToNSError(_vfs_error) ForFile:_path.c_str()] WaitForResult];
    };
    m_Job.m_OnCantCreateDestinationDir = [weak_self](int _vfs_error, string _path){
        auto strong_self = weak_self;
        return [[strong_self OnCantCreateDir:VFSError::ToNSError(_vfs_error) ForDir:_path.c_str()] WaitForResult];
    };
    m_Job.m_OnFileVerificationFailed = [weak_self](string _path){
        auto strong_self = weak_self;
        return [[strong_self OnFileVerificationFailed:_path.c_str()] WaitForResult];
    };
    
    m_Job.m_OnCantCreateDestinationRootDir = m_Job.m_OnCantCreateDestinationDir; // it's better to show another dialog in this case... later
    m_Job.m_OnDestinationFileReadError = m_Job.m_OnSourceFileReadError; // -""-
#pragma clang diagnostic pop
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
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to create a directory", @"Operations", "Error sheet prompt on dir creation")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantAccessSrcFile:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!self.isSingleFileCopy];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to access a file", @"Operations", "Title on error when source file is inaccessible")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyCantOpenDestFile:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!self.isSingleFileCopy];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to open a destination file", @"Operations", "Title on error when destination file can't be opened")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyReadError:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!self.isSingleFileCopy];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to read a file", @"Operations", "Error when reading failed")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCopyWriteError:(NSError*)_error ForFile:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!self.isSingleFileCopy];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to write a file", @"Operations", "Error when writing failed")];
    [alert SetInformativeText:[self buildInformativeStringForError:_error onPath:_path]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnFileVerificationFailed:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    [alert AddButtonWithTitle:@"OK" andResult:FileCopyOperationDR::Continue];
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Checksum verification failed!", @"Operations", "Error when verification failed")];
    [alert SetInformativeText:
     [NSString stringWithFormat:NSLocalizedStringFromTable(@"MD5 checksum mismatch found for path:\n%@", @"Operations", "Informative text for checksum verification failed"),
                  [NSString stringWithUTF8String:_path]]
     ];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnRenameDestinationExists:(const char *)_dest
                                             Source:(const char *)_src
{
    // TODO:
    // why we use here a different dialog, not one that used on copy operation?
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Rewrite", @"Operations", "User action button title to rewrite a file")
                    andResult:FileCopyOperationDR::Overwrite];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Abort", @"Operations", "User action button title to abort an operation")
                    andResult:FileCopyOperationDR::Stop];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Hide", @"Operations", "User action button title to hide an error sheet")
                    andResult:FileCopyOperationDR::None];
    
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
