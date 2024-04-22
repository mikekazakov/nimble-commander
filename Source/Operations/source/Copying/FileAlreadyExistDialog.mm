// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include <Carbon/Carbon.h>
#include "FileAlreadyExistDialog.h"
#include "../ModalDialogResponses.h"
#include "../Internal.h"
#include <Utility/StringExtras.h>
#include <Utility/SheetWithHotkeys.h>
#include <Utility/ObjCpp.h>

using namespace nc::ops;

@interface NCOpsFileAlreadyExistWindow : NCSheetWithHotkeys
@end

@implementation NCOpsFileAlreadyExistWindow

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
    if( event.type == NSEventTypeKeyDown && (event.modifierFlags & NSEventModifierFlagShift) &&
        event.keyCode == kVK_Return ) { // mimic Shift+Enter as enter so hotkey can trigger
        return [super performKeyEquivalent:[NSEvent keyEventWithType:NSEventTypeKeyDown
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

@property(strong, nonatomic) IBOutlet NSTextField *TargetFilename;
@property(strong, nonatomic) IBOutlet NSTextField *NewFileSize;
@property(strong, nonatomic) IBOutlet NSTextField *ExistingFileSize;
@property(strong, nonatomic) IBOutlet NSTextField *NewFileTime;
@property(strong, nonatomic) IBOutlet NSTextField *ExistingFileTime;
@property(strong, nonatomic) IBOutlet NSButton *RememberCheck;
@property(strong, nonatomic) IBOutlet NSButton *overwriteButton;
@property(strong, nonatomic) IBOutlet NSButton *skipButton;
@property(strong, nonatomic) IBOutlet NSButton *keepBothButton;
@property(strong, nonatomic) IBOutlet NSButton *appendButton;
@property(strong, nonatomic) IBOutlet NSButton *abortButton;

@end

static bool IsShiftPressed()
{
    return (NSEvent.modifierFlags & NSEventModifierFlagShift) != 0;
}

@implementation NCOpsFileAlreadyExistDialog {
    std::string m_DestPath;
    struct stat m_SourceStat;
    struct stat m_DestinationStat;
    std::shared_ptr<AsyncDialogResponse> m_Ctx;
}
@synthesize allowAppending;
@synthesize allowKeepingBoth;
@synthesize singleItem;
@synthesize TargetFilename;
@synthesize NewFileSize;
@synthesize ExistingFileSize;
@synthesize NewFileTime;
@synthesize ExistingFileTime;
@synthesize RememberCheck;
@synthesize overwriteButton;
@synthesize skipButton;
@synthesize keepBothButton;
@synthesize appendButton;
@synthesize abortButton;

- (id)initWithDestPath:(const std::string &)_path
         withSourceStat:(const struct stat &)_src_stat
    withDestinationStat:(const struct stat &)_dst_stat
             andContext:(std::shared_ptr<AsyncDialogResponse>)_ctx
{
    const auto nib_path = [Bundle() pathForResource:@"FileAlreadyExistDialog" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
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

    const auto old_date = [NSDate dateWithTimeIntervalSince1970:static_cast<double>(m_SourceStat.st_mtime)];
    self.NewFileTime.stringValue = [formatter stringFromDate:old_date];
    const auto new_date = [NSDate dateWithTimeIntervalSince1970:static_cast<double>(m_DestinationStat.st_mtime)];
    self.ExistingFileTime.stringValue = [formatter stringFromDate:new_date];

    self.NewFileSize.integerValue = m_SourceStat.st_size;
    self.ExistingFileSize.integerValue = m_DestinationStat.st_size;
    self.RememberCheck.state = NSControlStateValueOff;

    NCSheetWithHotkeys *sheet = nc::objc_cast<NCSheetWithHotkeys>(self.window);
    sheet.onCtrlA = [sheet makeClickHotkey:self.RememberCheck];
    sheet.onCtrlK = [sheet makeClickHotkey:self.keepBothButton];
    sheet.onCtrlO = [sheet makeClickHotkey:self.overwriteButton];
    sheet.onCtrlP = [sheet makeClickHotkey:self.appendButton];
    sheet.onCtrlS = [sheet makeClickHotkey:self.skipButton];
}

- (IBAction)OnOverwrite:(id) [[maybe_unused]] _sender
{
    [self endDialogWithReturnCode:NSModalResponseOverwrite];
}

- (IBAction)OnOverwriteOlder:(id) [[maybe_unused]] _sender
{
    [self endDialogWithReturnCode:NSModalResponseOverwriteOld];
}

- (IBAction)OnSkip:(id) [[maybe_unused]] _sender
{
    [self endDialogWithReturnCode:NSModalResponseSkip];
}

- (IBAction)OnAppend:(id) [[maybe_unused]] _sender
{
    [self endDialogWithReturnCode:NSModalResponseAppend];
}

- (IBAction)OnCancel:(id) [[maybe_unused]] _sender
{
    [self endDialogWithReturnCode:nc::ops::NSModalResponseStop];
}

- (IBAction)OnKeepBoth:(id) [[maybe_unused]] _sender
{
    [self endDialogWithReturnCode:NSModalResponseKeepBoth];
}

- (void)endDialogWithReturnCode:(NSInteger)_returnCode
{
    if( IsShiftPressed() )
        self.RememberCheck.state = NSControlStateValueOn;

    if( m_Ctx )
        m_Ctx->SetApplyToAll(self.RememberCheck.state == NSControlStateValueOn);

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
