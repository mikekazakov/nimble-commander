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
    if (self) {
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
    if (self) {
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
        self.Caption = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Deleting \u201c%@\u201d from \u201c%@\u201d",
                                                                             @"Operations",
                                                                             "Operation title for single item deletion"),
                        [NSString stringWithUTF8String:_files.front().c_str()],
                        dirname];
    else
        self.Caption = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Deleting %@ items from \u201c%@\u201d",
                                                                             @"Operations",
                                                                             "Operation title for multiple items deletion"),
                        [NSNumber numberWithUnsignedLong:_files.size()],
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
    
    if (stats.IsCurrentItemChanged()) {
        const char *item = stats.GetCurrentItem();
        if (!item)
            self.ShortInfo = @"";
        else
            self.ShortInfo = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Processing \u201c%@\u201d",
                                                                                   @"Operations",
                                                                                   "Operation info for file deletion"),
                              [NSString stringWithUTF8String:item]];
    }
}

- (OperationDialogAlert *)DialogOnOpendirError:(NSError*)_error ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
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

- (OperationDialogAlert *)DialogOnUnlinkError:(NSError*)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to delete a file",
                                                     @"Operations",
                                                     "Error dialog title when can't delete a file")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nPath: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on error dialog when can't delete a file"),
                               _error.localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnRmdirError:(NSError*)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to delete a directory",
                                                     @"Operations",
                                                     "Error dialog title when can't delete a directory")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nPath: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on error dialog when can't delete a directory"),
                               _error.localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnTrashItemError:(NSError *)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] init];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to move an item to Trash",
                                                     @"Operations",
                                                     "Error dialog title when can't move item to trash")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nPath: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on error dialog when can't trash an item"),
                               _error.localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Retry", @"Operations", "Error dialog button - retry an attempt")
                    andResult:OperationDialogResult::Retry];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Delete Permanently", @"Operations", "Error dialog button - delete file permanently")
                    andResult:FileDeletionOperationDR::DeletePermanently];
    if (!m_SingleItem) {
        [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Skip", @"Operations", "Error dialog button - skip current item")
                        andResult:OperationDialogResult::Skip];
        [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Skip All", @"Operations", "Error dialog button - skipp all items with errors")
                        andResult:OperationDialogResult::SkipAll];
    }
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Abort", @"Operations", "Error dialog button - abort operation")
                    andResult:OperationDialogResult::Stop];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Hide", @"Operations", "Error dialog button - hide dialog")
                    andResult:OperationDialogResult::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

- (OperationDialogAlert *)DialogOnSecureRewriteError:(NSError *)_error ForPath:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_SingleItem];
    
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to securely delete a file",
                                                     @"Operations",
                                                     "Error dialog title when can't securely delete a file")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nPath: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on error dialog when can't securely delete an item"),
                               _error.localizedDescription,
                               [NSString stringWithUTF8String:_path]]];
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
