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

@implementation FileCompressOperation
{
    FileCompressOperationJob m_Job;
    int m_LastInfoUpdateTime;
    bool m_HasTargetFn;
    bool m_NeedUpdateCaption;
    NSString *m_ArchiveName;
}

- (id)initWithFiles:(FlexChainedStringsChunk*)_src_files // passing with ownership, operation will free it on finish
            srcroot:(const char*)_src_root
             srcvfs:(shared_ptr<VFSHost>)_src_vfs
            dstroot:(const char*)_dst_root
             dstvfs:(shared_ptr<VFSHost>)_dst_vfs
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_Job.Init(_src_files, _src_root, _src_vfs, _dst_root, _dst_vfs, self);
        m_LastInfoUpdateTime = 0;
        m_HasTargetFn = false;
        m_NeedUpdateCaption = true;
        
//        self.Caption = @"Compressing..."; // TODO: need good title here, not a dummy
        self.Caption = @"";
    }
    return self;
}

- (void) ExtractTargetFn
{
    if(!m_HasTargetFn)
        if(strcmp(m_Job.TargetFileName(), "") != 0) {
            char tmp[MAXPATHLEN];
            if(GetFilenameFromPath(m_Job.TargetFileName(), tmp)) {
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
    
    int time = stats.GetTime();
    
    // titles stuff
    if(m_NeedUpdateCaption)
    {
        if(!m_HasTargetFn)
            [self ExtractTargetFn];
            
        if(m_HasTargetFn)
        {
            if(!m_Job.IsDoneScanning()) {
                self.Caption = [NSString stringWithFormat:@"Preparing to compress to \"%@\"", m_ArchiveName];
            }
            else {
                NSNumberFormatter *fmt = [NSNumberFormatter new];
                [fmt setNumberStyle:NSNumberFormatterDecimalStyle];
                
                self.Caption = [NSString stringWithFormat:@"Compressing %@ %@ to \"%@\"",
                                [fmt stringFromNumber:[NSNumber numberWithLong:m_Job.FilesAmount()]],
                                m_Job.FilesAmount() > 1 ? @"items" : @"item",
                                m_ArchiveName];
                m_NeedUpdateCaption = false;
            }
        }
    }

    if (time - m_LastInfoUpdateTime >= 1000) {
        self.ShortInfo = [self ProduceDescriptionStringForBytesProcess];
        m_LastInfoUpdateTime = time;
    }
}

- (OperationDialogAlert *)OnCantAccessSourceDir:(NSError*)_error forPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:true];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to access directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nPath: %@",
                               [_error localizedDescription],
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnCantAccessSourceItem:(NSError*)_error forPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:true];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to access item"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nPath: %@",
                               [_error localizedDescription],
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnReadError:(NSError*)_error forPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:true];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to read item's data"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nPath: %@",
                               [_error localizedDescription],
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)OnWriteError:(NSError*)_error
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:true];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Failed to write archive"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@", [_error localizedDescription]]];
    [self EnqueueDialog:alert];
    
    return alert;
}

- (void) SayAbout4Gb:(const char*) _path
{
    SyncMessageBoxNS([NSString stringWithFormat:@"Sorry, currently Files can't compress items larger than 4Gb.\nThis file will be skipped:\n%@",
                      [NSString stringWithUTF8String:_path] ]
                     );
}

- (void) OnFinish
{
    [super OnFinish];    
    
    if(!m_HasTargetFn)
        [self ExtractTargetFn];
    
    NSString *arc_name = m_ArchiveName;
    PanelController *target = self.TargetPanel;
    
    if(!arc_name)
        return;
    
    dispatch_to_main_queue( ^{
        [target RefreshDirectory];
        [target ScheduleDelayedSelectionChangeFor:arc_name
                                        timeoutms:500
                                         checknow:true];
    });
}

@end
