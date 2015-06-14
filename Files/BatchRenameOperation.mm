//
//  BatchRenameOperation.m
//  Files
//
//  Created by Michael G. Kazakov on 11/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "BatchRenameOperation.h"
#import "BatchRenameOperationJob.h"
#import "Common.h"

@implementation BatchRenameOperation
{
    BatchRenameOperationJob m_Job;
}

- (id)initWithOriginalFilepaths:(vector<string>&&)_src_paths
               renamedFilepaths:(vector<string>&&)_dst_paths
                            vfs:(VFSHostPtr)_src_vfs
{
    self = [super initWithJob:&m_Job];
    if (self) {
        
        self.Caption = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Batch renaming %u items",
                                                                             @"Operations",
                                                                             "Operation title batch renaming"),
                        _src_paths.size()];
        
        m_Job.Init(move(_src_paths), move(_dst_paths), _src_vfs, self);
    }
    return self;
}

- (void)Update
{
    OperationStats &stats = m_Job.GetStats();
    
    float progress = stats.GetProgress();
    if (self.Progress != progress)
        self.Progress = progress;

    if (stats.IsCurrentItemChanged()) {
        auto item = stats.GetCurrentItem();
        if (item.empty())
            self.ShortInfo = @"";
        else
            self.ShortInfo = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Processing \u201c%@\u201d",
                                                                                   @"Operations",
                                                                                   "Operation info for batch file renaming"),
                              [NSString stringWithUTF8StdString:item]];
    }
}

- (OperationDialogAlert *)DialogOnRenameError:(NSError*)_error source:(const string&)_source destination:(const string&)_destination
{
    OperationDialogAlert *alert = [[OperationDialogAlert alloc] initRetrySkipSkipAllAbortHide:true];
    [alert SetAlertStyle:NSCriticalAlertStyle];
    [alert SetMessageText:NSLocalizedStringFromTable(@"Failed to rename an item",
                                                     @"Operations",
                                                     "Error dialog title when can't rename an item when batch renaming")];
    [alert SetInformativeText:[NSString stringWithFormat:NSLocalizedStringFromTable(@"Error: %@\nOriginal path: %@\nNew path: %@",
                                                                                    @"Operations",
                                                                                    "Informative text on error dialog when can't rename an item when batch renaming"),
                               _error.localizedDescription,
                               [NSString stringWithUTF8StdString:_source],
                               [NSString stringWithUTF8StdString:_destination]]];
    [self EnqueueDialog:alert];
    return alert;
}

@end
