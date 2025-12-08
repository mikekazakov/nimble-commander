// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#import "HaltReasonDialog.h"
#include <VFS/VFS.h>
#include "Internal.h"

@interface NCOpsHaltReasonDialog ()
@property(strong, nonatomic) IBOutlet NSTextField *pathLabel;
@property(strong, nonatomic) IBOutlet NSTextField *errorLabel;
@property(strong, nonatomic) IBOutlet NSTextField *messageLabel;
@property(strong, nonatomic) IBOutlet NSImageView *appIcon;

@end

@implementation NCOpsHaltReasonDialog {
    NSString *m_Message;
    NSString *m_Path;
    NSString *m_Error;
}

@synthesize message = m_Message;
@synthesize path = m_Path;
@synthesize pathLabel;
@synthesize errorLabel;
@synthesize messageLabel;
@synthesize appIcon;

- (instancetype)init
{
    using namespace nc::ops;
    const auto nib_path = [Bundle() pathForResource:@"HaltReasonDialog" ofType:@"nib"];
    self = [super initWithWindowNibPath:nib_path owner:self];
    if( self ) {
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.pathLabel.stringValue = m_Path ? m_Path : @"";
    self.errorLabel.stringValue = m_Error ? m_Error : @"";
    self.messageLabel.stringValue = m_Message ? m_Message : @"";
    self.appIcon.image = [NSApp applicationIconImage];
    NSBeep();
}

- (IBAction)onClose:(id) [[maybe_unused]] _sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)setError:(nc::Error)_error
{
    m_Error = [NSString stringWithUTF8String:_error.LocalizedFailureReason().c_str()];
}

@end

@interface NCOpsHaltReasonDialogWindow : NSWindow
@end

@implementation NCOpsHaltReasonDialogWindow
- (void)cancelOperation:(id) [[maybe_unused]] _sender
{
    [self.sheetParent endSheet:self returnCode:NSModalResponseCancel];
}
@end
