//
//  FileAlreadyExistSheetController.m
//  Directories
//
//  Created by Michael G. Kazakov on 16.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Carbon/Carbon.h>
#include "../../GoogleAnalytics.h"
#include "../Operation.h"
#include "DialogResults.h"
#include "FileAlreadyExistSheetController.h"
#include "FileCopyOperation.h"

@interface FileAlreadyExistSheetWindow : NSPanel
@end

@implementation FileAlreadyExistSheetWindow

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    if( event.type == NSKeyDown &&
        (event.modifierFlags & NSEventModifierFlagShift) &&
        event.keyCode == kVK_Return) { // mimic Shift+Enter as enter so hotkey can trigger
        return [super performKeyEquivalent:[NSEvent keyEventWithType:NSKeyDown
                                                            location:event.locationInWindow
                                                       modifierFlags:0
                                                           timestamp:event.timestamp
                                                        windowNumber:event.windowNumber
                                                             context:nil
                                                          characters:@"\r"
                                         charactersIgnoringModifiers:@"\r"
                                                           isARepeat:false
                                                             keyCode:kVK_Return]];
    }
    return [super performKeyEquivalent:event];
}

@end


@interface FileAlreadyExistSheetController ()

@property (strong) IBOutlet NSTextField *TargetFilename;
@property (strong) IBOutlet NSTextField *NewFileSize;
@property (strong) IBOutlet NSTextField *ExistingFileSize;
@property (strong) IBOutlet NSTextField *NewFileTime;
@property (strong) IBOutlet NSTextField *ExistingFileTime;
@property (strong) IBOutlet NSButton *RememberCheck;
- (IBAction)OnOverwrite:(id)sender;
- (IBAction)OnOverwriteOlder:(id)sender;
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

static bool IsShiftPressed()
{
    return (NSEvent.modifierFlags & NSEventModifierFlagShift) != 0;
}

@implementation FileAlreadyExistSheetController
{
    string m_DestPath;
    struct stat m_SourceStat;
    struct stat m_DestinationStat;
    shared_ptr<bool> m_ApplyToAll;
    __weak Operation *m_Operation;
}
@synthesize Result = m_Result;
@synthesize applyToAll = m_ApplyToAll;

- (id)initWithDestPath:(const string&)_path
        withSourceStat:(const struct stat &)_src_stat
   withDestinationStat:(const struct stat &)_dst_stat
{
    self = [super init];
    if(self) {
        m_DestPath = _path;
        m_SourceStat = _src_stat;
        m_DestinationStat = _dst_stat;
        self.allowAppending = true;
        self.singleItem = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.TargetFilename.stringValue = [NSString stringWithUTF8StdString:m_DestPath];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterMediumStyle;
    formatter.dateStyle = NSDateFormatterMediumStyle;
    self.NewFileTime.stringValue = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:m_SourceStat.st_mtime]];
    self.ExistingFileTime.stringValue = [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:m_DestinationStat.st_mtime]];
    
    self.NewFileSize.integerValue = m_SourceStat.st_size;
    self.ExistingFileSize.integerValue = m_DestinationStat.st_size;
    self.RememberCheck.state = NSOffState;
    
    GoogleAnalytics::Instance().PostScreenView("File Copy Already Exists");
}

- (void)showDialogForWindow:(NSWindow *)_parent
{
    dispatch_assert_main_queue();

    [super beginSheetForWindow:_parent completionHandler:^(NSModalResponse returnCode) {
        if( m_ApplyToAll )
            *m_ApplyToAll = self.RememberCheck.state == NSOnState;
        
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
    if( IsShiftPressed()  )
        self.RememberCheck.state = NSOnState;
    
    [super endSheet:FileCopyOperationDR::Overwrite];
}

- (IBAction)OnOverwriteOlder:(id)sender
{
    if( IsShiftPressed()  )
        self.RememberCheck.state = NSOnState;
    
    [super endSheet:FileCopyOperationDR::OverwriteOld];
}

- (IBAction)OnSkip:(id)sender
{
    if( IsShiftPressed()  )
        self.RememberCheck.state = NSOnState;
    
    [super endSheet:OperationDialogResult::Skip];
}

- (IBAction)OnAppend:(id)sender
{
    if( IsShiftPressed()  )
        self.RememberCheck.state = NSOnState;
    
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

- (void)moveRight:(id)sender
{
    [self.window selectNextKeyView:sender];
}

- (void)moveLeft:(id)sender
{
    [self.window selectPreviousKeyView:sender];
}

@end
