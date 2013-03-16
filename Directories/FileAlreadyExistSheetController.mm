//
//  FileAlreadyExistSheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 16.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FileAlreadyExistSheetController.h"
#include "Common.h"

@implementation FileAlreadyExistSheetController
{
    FileAlreadyExistSheetCompletionHandler m_Handler;
    NSString *m_DestPath;
    unsigned long m_NewSize;
    time_t m_NewTime;
    unsigned long m_ExiSize;
    time_t m_ExiTime;
}

- (id)init {
    self = [super initWithWindowNibName:@"FileAlreadyExistSheetController"];
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
    
    [[self window] setDefaultButtonCell:[[self OverwriteButton] cell]];
}

- (void)ShowSheet: (NSWindow *)_window
         destpath: (NSString*)_path
          newsize: (unsigned long)_newsize
          newtime: (time_t) _newtime
          exisize: (unsigned long)_exisize
          exitime: (time_t) _exitime
          handler: (FileAlreadyExistSheetCompletionHandler)_handler
{
    m_DestPath = _path;
    m_NewSize = _newsize;
    m_NewTime = _newtime;
    m_ExiSize = _exisize;
    m_ExiTime = _exitime;
    m_Handler = _handler;
    
    dispatch_async(dispatch_get_main_queue(), ^(){
    [NSApp beginSheet: [self window]
       modalForWindow: _window
        modalDelegate: self
       didEndSelector: @selector(didEndSheet:returnCode:contextInfo:)
          contextInfo: nil];
    });
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    [[self window] orderOut:self];
    
    if(m_Handler)
        m_Handler((int)returnCode, [[self RememberCheck] state] == NSOnState);
}

- (IBAction)OnOverwrite:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Overwrite];
}

- (IBAction)OnSkip:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Skip];
}

- (IBAction)OnAppend:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Append];
}

- (IBAction)OnRename:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Rename];
}

- (IBAction)OnCancel:(id)sender
{
    [NSApp endSheet:[self window] returnCode:DialogResult::Cancel];
}

@end
