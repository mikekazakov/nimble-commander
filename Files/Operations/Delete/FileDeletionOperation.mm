//
//  FileDeletionOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "../OperationDialogAlert.h"
#include "FileDeletionOperation.h"
#include "Job.h"

static NSString *Caption(const vector<VFSListingItem> &_files)
{
    if(_files.size() == 1)
        return  [NSString stringWithFormat:NSLocalizedStringFromTable(@"Deleting \u201c%@\u201d",
                                                                      @"Operations",
                                                                      "Operation title for single item deletion"),
                 [NSString stringWithUTF8String:_files.front().Name()]];
    else
        return [NSString stringWithFormat:NSLocalizedStringFromTable(@"Deleting %@ items",
                                                                     @"Operations",
                                                                     "Operation title for multiple items deletion"),
                [NSNumber numberWithUnsignedLong:_files.size()]];
}

@implementation FileDeletionOperation
{
    FileDeletionOperationJobNew m_Job;
}

- (id)initWithFiles:(vector<VFSListingItem>)_files
               type:(FileDeletionOperationType)_type
{
    self = [super initWithJob:&m_Job];
    if (self) {
        self.Caption = Caption(_files);
        
        m_Job.Init(move(_files), _type);
        
        __weak auto weak_self = self;
        self.Stats.RegisterObserver(OperationStats::Nofity::CurrentItem,
                                    nullptr,
                                    [weak_self]{ if(auto self = weak_self) [self updateShortInfo]; }
                                    );
        m_Job.m_OnCantUnlink = [weak_self](int _vfs_error, string _path){
            auto self = weak_self;
            return [[self DialogOnUnlinkError:VFSError::ToNSError(_vfs_error) ForPath:_path.c_str()] WaitForResult];
        };
        m_Job.m_OnCantRmdir =  [weak_self](int _vfs_error, string _path){
            auto self = weak_self;
            return [[self DialogOnRmdirError:VFSError::ToNSError(_vfs_error) ForPath:_path.c_str()] WaitForResult];
        };
        m_Job.m_OnCantTrash =  [weak_self](int _vfs_error, string _path){
            auto self = weak_self;
            return [[self DialogOnTrashItemError:VFSError::ToNSError(_vfs_error) ForPath:_path.c_str()] WaitForResult];
        };
    }
    
    return self;
}

- (void)Update
{
}

- (void)updateShortInfo
{
    auto item = self.Stats.GetCurrentItem();
    if (item->empty())
        self.ShortInfo = @"";
    else
        self.ShortInfo = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Processing \u201c%@\u201d",
                                                                               @"Operations",
                                                                               "Operation info for file deletion"),
                          [NSString stringWithUTF8StdString:*item]];
    
    self.Progress = self.Stats.GetProgress();
}

- (OperationDialogAlert *)DialogOnOpendirError:(NSError*)_error ForDir:(const char *)_path
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc]
                                   initRetrySkipSkipAllAbortHide:!m_Job.IsSingleItem()];
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
                                   initRetrySkipSkipAllAbortHide:!m_Job.IsSingleItem()];
    
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
                                   initRetrySkipSkipAllAbortHide:!m_Job.IsSingleItem()];
    
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
                    andResult:FileDeletionOperationDR::Retry];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Delete Permanently", @"Operations", "Error dialog button - delete file permanently")
                    andResult:FileDeletionOperationDR::DeletePermanently];
    if (!m_Job.IsSingleItem()) {
        [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Skip", @"Operations", "Error dialog button - skip current item")
                        andResult:FileDeletionOperationDR::Skip];
        [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Skip All", @"Operations", "Error dialog button - skipp all items with errors")
                        andResult:FileDeletionOperationDR::SkipAll];
    }
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Abort", @"Operations", "Error dialog button - abort operation")
                    andResult:FileDeletionOperationDR::Stop];
    [alert AddButtonWithTitle:NSLocalizedStringFromTable(@"Hide", @"Operations", "Error dialog button - hide dialog")
                    andResult:FileDeletionOperationDR::None];
    
    [self EnqueueDialog:alert];
    
    return alert;
}

@end
