//
//  FileDeletionOperation.m
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileDeletionOperation.h"
#import "FileDeletionOperationJob.h"
#import "OperationDialogAlert.h"
#import "Common.h"

@implementation FileDeletionOperation
{
    FileDeletionOperationJob m_Job;
    BOOL m_SingleItem;
    
}

// _files - passing with ownership, operation will free it on finish
- (id)initWithFiles:(FlexChainedStringsChunk*)_files
               type:(FileDeletionOperationType)_type
           rootpath:(const char*)_path
{
    self = [super initWithJob:&m_Job];
    if (self)
    {
        m_SingleItem = _files->Amount() == 1;
        
        m_Job.Init(_files, _type, _path, self);
        
        // Set caption.
        char buff[128] = {0};
        GetDirectoryFromPath(_path, buff, 128);
        if (_files->Amount() == 1)
        {
            self.Caption = [NSString stringWithFormat:@"Deleting \"%@\" from \"%@\"",
                            [NSString stringWithUTF8String:(*_files)[0].str()],
                            [NSString stringWithUTF8String:buff]];
        }
        else
        {
            self.Caption = [NSString stringWithFormat:@"Deleting %i items from \"%@\"",
                            _files->CountStringsWithDescendants(),
                            [NSString stringWithUTF8String:buff]];
        }
    }
    return self;
}   

- (void)Update
{
    OperationStats &stats = m_Job.GetStats();
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
