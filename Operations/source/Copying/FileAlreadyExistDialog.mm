// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include <Carbon/Carbon.h>
#include "FileAlreadyExistDialog.h"
#include "../ModalDialogResponses.h"
#include <Utility/StringExtras.h>

using namespace nc::ops;

@interface NCOpsFileAlreadyExistWindow : NSWindow
@end

@implementation NCOpsFileAlreadyExistWindow

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


@interface NCOpsFileAlreadyExistDialog ()

@property (strong) IBOutlet NSTextField *TargetFilename;
@property (strong) IBOutlet NSTextField *NewFileSize;
@property (strong) IBOutlet NSTextField *ExistingFileSize;
@property (strong) IBOutlet NSTextField *NewFileTime;
@property (strong) IBOutlet NSTextField *ExistingFileTime;
@property (strong) IBOutlet NSButton *RememberCheck;

@end

static bool IsShiftPressed()
{
    return (NSEvent.modifierFlags & NSEventModifierFlagShift) != 0;
}

@implementation NCOpsFileAlreadyExistDialog
{
    std::string m_DestPath;
    struct stat m_SourceStat;
    struct stat m_DestinationStat;
    std::shared_ptr<AsyncDialogResponse> m_Ctx;
}

- (id)initWithDestPath:(const std::string&)_path
        withSourceStat:(const struct stat &)_src_stat
   withDestinationStat:(const struct stat &)_dst_stat
            andContext:(std::shared_ptr<AsyncDialogResponse>)_ctx
{
    self = [super initWithWindowNibName:@"FileAlreadyExistDialog"];
    if(self) {
        m_DestPath = _path;
        m_SourceStat = _src_stat;
        m_DestinationStat = _dst_stat;
        m_Ctx = _ctx;
        self.allowAppending = true;
        self.allowKeepingBoth = false;
        self.singleItem = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.TargetFilename.stringValue = [NSString stringWithUTF8StdString:m_DestPath];
    
    const auto formatter = [[NSDateFormatter alloc] init];
    formatter.timeStyle = NSDateFormatterMediumStyle;
    formatter.dateStyle = NSDateFormatterMediumStyle;
    
    const auto old_date = [NSDate dateWithTimeIntervalSince1970:m_SourceStat.st_mtime];
    self.NewFileTime.stringValue = [formatter stringFromDate:old_date];
    const auto new_date = [NSDate dateWithTimeIntervalSince1970:m_DestinationStat.st_mtime];
    self.ExistingFileTime.stringValue = [formatter stringFromDate:new_date];
    
    self.NewFileSize.integerValue = m_SourceStat.st_size;
    self.ExistingFileSize.integerValue = m_DestinationStat.st_size;
    self.RememberCheck.state = NSOffState;
}

- (IBAction)OnOverwrite:(id)sender
{
    [self endDialogWithReturnCode:NSModalResponseOverwrite];
}

- (IBAction)OnOverwriteOlder:(id)sender
{
    [self endDialogWithReturnCode:NSModalResponseOverwriteOld];
}

- (IBAction)OnSkip:(id)sender
{
    [self endDialogWithReturnCode:NSModalResponseSkip];
}

- (IBAction)OnAppend:(id)sender
{
    [self endDialogWithReturnCode:NSModalResponseAppend];
}

- (IBAction)OnCancel:(id)sender
{
    [self endDialogWithReturnCode:nc::ops::NSModalResponseStop];
}

- (IBAction)OnKeepBoth:(id)sender
{
    [self endDialogWithReturnCode:NSModalResponseKeepBoth];
}

- (void)endDialogWithReturnCode:(NSInteger)_returnCode
{
    if( IsShiftPressed()  )
        self.RememberCheck.state = NSOnState;
    
    if( m_Ctx )
        m_Ctx->SetApplyToAll( self.RememberCheck.state == NSOnState );
    
    [self.window.sheetParent endSheet:self.window returnCode:_returnCode];
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
