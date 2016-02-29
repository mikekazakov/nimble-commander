//
//  FileAlreadyExistSheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 16.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "../../Common.h"
#include "../Operation.h"
#include "DialogResults.h"
#include "FileAlreadyExistSheetController.h"
#include "FileCopyOperation.h"

@interface FileAlreadyExistSheetController ()

@property (strong) IBOutlet NSTextField *TargetFilename;
@property (strong) IBOutlet NSTextField *NewFileSize;
@property (strong) IBOutlet NSTextField *ExistingFileSize;
@property (strong) IBOutlet NSTextField *NewFileTime;
@property (strong) IBOutlet NSTextField *ExistingFileTime;
@property (strong) IBOutlet NSButton *RememberCheck;
@property (strong) IBOutlet NSButton *OverwriteButton;
- (IBAction)OnOverwrite:(id)sender;
- (IBAction)OnSkip:(id)sender;
- (IBAction)OnAppend:(id)sender;
- (IBAction)OnRename:(id)sender;
- (IBAction)OnCancel:(id)sender;
- (IBAction)OnHide:(id)sender;

// protocol implementation
- (void)showDialogForWindow:(NSWindow *)_parent;
- (BOOL)IsVisible;
- (void)HideDialog;
- (void)CloseDialogWithResult:(int)_result;
- (int)WaitForResult;
- (void)OnDialogEnqueued:(Operation *)_operation;

@end

@implementation FileAlreadyExistSheetController
{
    NSString *m_DestPath;
    unsigned long m_NewSize;
    time_t m_NewTime;
    unsigned long m_ExiSize;
    time_t m_ExiTime;
    bool *m_Remember;
    bool m_Single;
    __weak Operation *m_Operation;
}
@synthesize Result = m_Result;

- (id)initWithFile: (const char*)_path
           newsize: (unsigned long)_newsize
           newtime: (time_t) _newtime
           exisize: (unsigned long)_exisize
           exitime: (time_t) _exitime
          remember:(bool*)  _remb
            single: (bool) _single
{
    self = [super init];
    if(self) {
        m_DestPath = [NSString stringWithUTF8String: _path];
        m_NewSize = _newsize;
        m_NewTime = _newtime;
        m_ExiSize = _exisize;
        m_ExiTime = _exitime;
        m_Remember = _remb;
        m_Single = _single;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
   [[self TargetFilename] setStringValue:m_DestPath];
    
    {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setTimeStyle:NSDateFormatterMediumStyle];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        NSDate *newtime = [NSDate dateWithTimeIntervalSince1970:m_NewTime];
        [[self NewFileTime] setStringValue:[formatter stringFromDate:newtime]];
    }

    {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setTimeStyle:NSDateFormatterMediumStyle];
        [formatter setDateStyle:NSDateFormatterMediumStyle];
        NSDate *newtime = [NSDate dateWithTimeIntervalSince1970:m_ExiTime];
        [[self ExistingFileTime] setStringValue:[formatter stringFromDate:newtime]];
    }
    
    [[self NewFileSize] setIntegerValue:m_NewSize];
    [[self ExistingFileSize] setIntegerValue:m_ExiSize];
    [[self RememberCheck] setState:NSOffState];
    [[self RememberCheck] setHidden:m_Single];
}

- (void)showDialogForWindow:(NSWindow *)_parent
{
    dispatch_assert_main_queue();

    [super beginSheetForWindow:_parent completionHandler:^(NSModalResponse returnCode) {
        *m_Remember = [[self RememberCheck] state] == NSOnState;
        m_Result = (int)returnCode;
        if (m_Result != OperationDialogResult::None)
            [(Operation*)m_Operation OnDialogClosed:self];
    }];
}

- (BOOL)IsVisible
{
    return self.window.isVisible;
}

- (void)HideDialog
{
    if( self.IsVisible )
        [super endSheet:OperationDialogResult::None];
}

- (void)CloseDialogWithResult:(int)_result
{
    if( _result == OperationDialogResult::None )
        return;
    
    [self HideDialog];
    m_Result = _result;
    if (m_Result != OperationDialogResult::None)
        [(Operation*)m_Operation OnDialogClosed:self];
}

- (void)OnDialogEnqueued:(Operation *)_operation
{
    m_Operation = _operation;
    m_Result = OperationDialogResult::None;
}

- (int)WaitForResult
{
    dispatch_assert_background_queue();
    
    while( self.Result == OperationDialogResult::None )
        usleep(33*1000);
    
    return self.Result;
}

- (IBAction)OnOverwrite:(id)sender
{
    [super endSheet:FileCopyOperationDR::Overwrite];
}

- (IBAction)OnSkip:(id)sender
{
    [super endSheet:OperationDialogResult::Skip];
}

- (IBAction)OnAppend:(id)sender
{
    [super endSheet:FileCopyOperationDR::Append];
}

- (IBAction)OnRename:(id)sender
{
    // TODO: implement me later
}

- (IBAction)OnCancel:(id)sender
{
    [super endSheet:OperationDialogResult::Stop];
}

- (IBAction)OnHide:(id)sender {
    [super endSheet:OperationDialogResult::None];
}

@end
