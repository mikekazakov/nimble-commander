//
//  FileCompressOperation.m
//  Files
//
//  Created by Michael G. Kazakov on 21.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileCompressOperation.h"
#import "FileCompressOperationJob.h"
#import "Common.h"
#import "PanelController.h"

static NSString *OpTitle(unsigned _amount, NSString *_target)
{
    if(_amount == 1)
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing 1 item to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                        _target];
    else if(_amount == 2)
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing 2 items to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                _target];
    else if(_amount == 3)
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing 3 items to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                _target];
    else if(_amount == 4)
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing 4 items to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                _target];
    else if(_amount == 5)
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing 5 items to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                _target];
    else if(_amount == 6)
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing 6 items to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                _target];
    else if(_amount == 7)
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing 7 items to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                _target];
    else if(_amount == 8)
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing 8 items to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                _target];
    else if(_amount == 9)
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing 9 items to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                _target];
    else
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Compressing %@ items to \u201c%@\u201d",
                                                                     @"Operations",
                                                                     "Operation title for compression"),
                [NSNumber numberWithUnsignedInt:_amount],
                _target];
}

@implementation FileCompressOperation
{
    FileCompressOperationJob m_Job;
    milliseconds m_LastInfoUpdateTime;
    bool m_HasTargetFn;
    bool m_NeedUpdateCaption;
    NSString *m_ArchiveName;
}

- (id)initWithFiles:(vector<VFSListingItem>)_src_files
            dstroot:(const string&)_dst_root
             dstvfs:(VFSHostPtr)_dst_vfs;
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(move(_src_files), _dst_root, _dst_vfs);
        m_LastInfoUpdateTime = 0ms;
        m_HasTargetFn = false;
        m_NeedUpdateCaption = true;
        self.Caption = @"";
  
        __weak FileCompressOperation* weak_self = self;
        m_Job.SetOnCantAccessSourceItem([=](int _vfs_error, string _path){
            if( FileCompressOperation* strong_self = weak_self )
                return [[strong_self OnCantAccessSourceItem:VFSError::ToNSError(_vfs_error) forPath:_path.c_str()] WaitForResult];
            return OperationDialogResult::Stop;
        });
        m_Job.SetOnCantAccessSourceDirectory([=](int _vfs_error, string _path){
            if( FileCompressOperation* strong_self = weak_self )
                return [[strong_self OnCantAccessSourceDir:VFSError::ToNSError(_vfs_error) forPath:_path.c_str()] WaitForResult];
            return OperationDialogResult::Stop;
        });
        m_Job.SetOnCantReadSourceItem([=](int _vfs_error, string _path){
            if( FileCompressOperation* strong_self = weak_self )
                return [[strong_self OnReadError:VFSError::ToNSError(_vfs_error) forPath:_path.c_str()] WaitForResult];
            return OperationDialogResult::Stop;
        });
        m_Job.SetOnCantWriteArchive([=](int _vfs_error){
            if( FileCompressOperation* strong_self = weak_self )
                return [[strong_self OnWriteError:VFSError::ToNSError(_vfs_error)] WaitForResult];
            return OperationDialogResult::Stop;
        });
    }
    return self;
}

- (void) ExtractTargetFn
{
    if(!m_HasTargetFn)
        if( !m_Job.TargetFileName().empty() ) {
            char tmp[MAXPATHLEN];
            if( GetFilenameFromPath(m_Job.TargetFileName().c_str(), tmp) ) {
                m_ArchiveName = [NSString stringWithUTF8String:tmp];
                m_HasTargetFn = true;
            }
        }
}

- (void)Update
{
    OperationStats &stats = m_Job.GetStats();
    float progress = stats.GetProgress();
    if (self.Progress != progress)
        self.Progress = progress;
    
    milliseconds time = stats.GetTime();
    
    // titles stuff
    if(m_NeedUpdateCaption) {
        if(!m_HasTargetFn)
            [self ExtractTargetFn];
            
        if(m_HasTargetFn) {
            if(!m_Job.IsDoneScanning()) {
                self.Caption = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Preparing to compress to \u201c%@\u201d",
                                                                                     @"Operations",
                                                                                     "Operation title for compression"),
                                m_ArchiveName];
            }
            else {
                self.Caption = OpTitle(m_Job.FilesAmount(), m_ArchiveName);
                m_NeedUpdateCaption = false;
            }
        }
    }

    if (time - m_LastInfoUpdateTime >= 1000ms) {
        self.ShortInfo = [self ProduceDescriptionStringForBytesProcess];
        m_LastInfoUpdateTime = time;
    }
}

- (OperationDialogAlert *)OnCantAccessSourceDir:(NSError*)_error forPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:true];
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to access a directory",
                                                     @"Operations",
                                                     "Error dialog title when can't traverse a directory")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nDirectory: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on error dialog when can't access a directory"),
                               _error.localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)OnCantAccessSourceItem:(NSError*)_error forPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:true];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to access a file",
                                                     @"Operations",
                                                     "Title on error when source file is inaccessible")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nPath: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on error dialog when can't access a file"),
                               _error.localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnReadError:(NSError*)_error forPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:true];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to read a file",
                                                     @"Operations",
                                                     "Title on error when source file can't be read")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nPath: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on error dialog when can't read a file"),
                               _error.localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnWriteError:(NSError*)_error
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:true];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to write an archive",
                                                     @"Operations",
                                                     "Title on error when archive target can't be written")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on error dialog when can't write an archive"),
                               _error.localizedDescription]];
    [self EnqueueDialog:alert];
    
    return alert;
}

- (void) OnFinish
{
    [super OnFinish];    
    
    if(!m_HasTargetFn)
        [self ExtractTargetFn];
    
    string arc_name = m_ArchiveName.UTF8String;
    PanelController *target = self.TargetPanel;
    
    dispatch_to_main_queue( [=]{
        [target RefreshDirectory];
        PanelControllerDelayedSelection req;
        req.filename = arc_name;
        [target ScheduleDelayedSelectionChangeFor:req];
    });
}

@end
