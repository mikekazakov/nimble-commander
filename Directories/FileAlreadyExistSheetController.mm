//
//  FileAlreadyExistSheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 16.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileAlreadyExistSheetController.h"
#import "FileCopyOperation.h"
#import "Operation.h"
#import "Common.h"

@implementation FileAlreadyExistSheetController
{
    NSString *m_DestPath;
    unsigned long m_NewSize;
    time_t m_NewTime;
    unsigned long m_ExiSize;
    time_t m_ExiTime;
    bool *m_Remember;
    bool m_Single;
    Operation *m_Operation;    
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
    self = [super initWithWindowNibName:@"FileAlreadyExistSheetController"];
    if(self)
    {
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
        
    [[self window] setDefaultButtonCell:[[self OverwriteButton] cell]];
}

- (void)ShowDialogForWindow:(NSWindow *)_parent
{
    dispatch_async(dispatch_get_main_queue(), ^(){ // really need this dispatch_async?
        [NSApp beginSheet: [self window]
           modalForWindow: _parent
            modalDelegate: self
           didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
              contextInfo: nil];
    });
}

- (BOOL)IsVisible
{
    return [[self window] isVisible];
}

- (void)HideDialog
{
    [NSApp endSheet:[self window] returnCode:OperationDialogResult::None];
}

- (void)CloseDialogWithResult:(int)_result
{
    assert(_result != OperationDialogResult::None);
    
    if ([self IsVisible])
        [NSApp endSheet:[self window] returnCode:_result];
    else
    {
        m_Result = _result;
        
        if (m_Result != OperationDialogResult::None)
            [m_Operation OnDialogClosed:self];
    }
}

- (void)OnDialogEnqueued:(Operation *)_operation
{
    m_Operation = _operation;
    m_Result = OperationDialogResult::None;
}

- (int)WaitForResult
{
    while (self.Result == OperationDialogResult::None)
    {
        usleep(33*1000);
    }
    
    return self.Result;
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    
    m_Result = (int)returnCode;
    *m_Remember = [[self RememberCheck] state] == NSOnState;

    if (m_Result != OperationDialogResult::None)
        [m_Operation OnDialogClosed:self];
}

- (IBAction)OnOverwrite:(id)sender
{
    [NSApp endSheet:[self window] returnCode:FileCopyOperationDR::Overwrite];
}

- (IBAction)OnSkip:(id)sender
{
    [NSApp endSheet:[self window] returnCode:FileCopyOperationDR::Skip];
}

- (IBAction)OnAppend:(id)sender
{
    [NSApp endSheet:[self window] returnCode:FileCopyOperationDR::Append];
}

- (IBAction)OnRename:(id)sender
{
//    [NSApp endSheet:[self window] returnCode:DialogResult::Rename];
    // TODO: implement me later
}

- (IBAction)OnCancel:(id)sender
{
    [NSApp endSheet:[self window] returnCode:OperationDialogResult::Stop];
}

- (IBAction)OnHide:(id)sender {
    [NSApp endSheet:[self window] returnCode:OperationDialogResult::None];
}

@end
