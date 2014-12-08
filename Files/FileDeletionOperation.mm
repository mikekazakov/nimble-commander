//
//  FileDeletionOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileDeletionOperation.h"
#import "FileDeletionOperationJob.h"
#import "FileDeletionOperationVFSJob.h"
#import "OperationDialogAlert.h"
#import "Common.h"
#import "PanelController.h"

@implementation FileDeletionOperation
{
    unique_ptr<FileDeletionOperationJob> m_NativeJob;
    unique_ptr<FileDeletionOperationVFSJob> m_VFSJob;
    
    bool m_SingleItem;
}

- (id)initWithFiles:(vector<string>&&)_files
               type:(FileDeletionOperationType)_type
                dir:(const string&)_path
{
    m_NativeJob = make_unique<FileDeletionOperationJob>();
    self = [super initWithJob:m_NativeJob.get()];
    if (self)
    {
        [self initCommon:_files rootpath:_path];
        m_NativeJob->Init(move(_files), _type, _path, self);
    }
    return self;
}   

- (id)initWithFiles:(vector<string>&&)_files
                dir:(const string&)_path
                 at:(const VFSHostPtr&)_host
{
    m_VFSJob = make_unique<FileDeletionOperationVFSJob>();
    self = [super initWithJob:m_VFSJob.get()];
    if (self)
    {
        [self initCommon:_files rootpath:_path];
        m_VFSJob->Init(move(_files), _path, _host, self);
    }
    return self;
}

- (void)initCommon:(const vector<string>&)_files rootpath:(path)_path
{
    m_SingleItem = _files.size() == 1;
    
    if(_path.filename() == ".") _path.remove_filename();
    NSString *dirname = [NSString stringWithUTF8String:_path.filename().c_str()];
    
    if(m_SingleItem)
        self.Caption = [NSString stringWithFormat:@"Deleting \"%@\" from \"%@\"",
                        [NSString stringWithUTF8String:_files.front().c_str()],
                        dirname];
    else
        self.Caption = [NSString stringWithFormat:@"Deleting %lu items from \"%@\"",
                        _files.size(),
                        dirname];
    
    [self AddOnFinishHandler:^{
        if(self.TargetPanel != nil) {
            dispatch_to_main_queue( [=]{
                [self.TargetPanel RefreshDirectory];
            });
        }
    }];
}

- (void)Update
{
    OperationStats &stats = m_NativeJob ? m_NativeJob->GetStats() : m_VFSJob->GetStats();
    
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

- (OperationDialogAlert *)DialogOnOpendirError:(int)_error ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Directory access error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nDirectory: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnVFSIterError:(int)_error ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Directory access error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nDirectory: %@",
                                [VFSError::ToNSError(_error) localizedDescription],
                               [NSString stringWithUTF8String:_path]]];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogOnStatError:(int)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Can't get file status"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnUnlinkError:(int)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Can't delete file"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnVFSUnlinkError:(int)_error For:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Can't delete file"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nPath: %@",
                               [VFSError::ToNSError(_error) localizedDescription],
                               [NSString stringWithUTF8String:_path]]];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogOnRmdirError:(int)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Can't delete directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %s\nPath: %@",
                               strerror(_error), [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnVFSRmdirError:(int)_error For:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Can't delete directory"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Error: %@\nPath: %@",
                               [VFSError::ToNSError(_error) localizedDescription],
                               [NSString stringWithUTF8String:_path]]];
    [self EnqueueDialog:alert];
    return alert;
}

- (OperationDialogAlert *)DialogOnTrashItemError:(NSError *)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Delete error"];
    [alert SetInformativeText:[NSString stringWithFormat:@"Can't move %@ to trash.\nError: %@",
                               [NSString stringWithUTF8String:_path], [_error localizedDescription]]];
    
    [alert AddButtonWithTitle:@"Retry" andResult:OperationDialogResult::Retry];
    [alert AddButtonWithTitle:@"Delete"
                    andResult:FileDeletionOperationDR::DeletePermanently];
    if (!m_SingleItem)
    {
        [alert AddButtonWithTitle:@"Skip" andResult:OperationDialogResult::Skip];
        [alert AddButtonWithTitle:@"Skip All" andResult:OperationDialogResult::SkipAll];
    }
    [alert AddButtonWithTitle:@"Abort" andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:@"Hide" andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnSecureRewriteError:(int)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:@"Secure delete error"];
    [alert SetInformativeText:[NSString
                               stringWithFormat:@"Can't access or modify file %@./nError: %s",
                               [NSString stringWithUTF8String:_path], strerror(_error)]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
