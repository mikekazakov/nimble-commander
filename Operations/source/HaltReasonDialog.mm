// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#import "HaltReasonDialog.h"
#include <VFS/VFS.h>

@interface NCOpsHaltReasonDialog ()
@property (strong) IBOutlet NSTextField *pathLabel;
@property (strong) IBOutlet NSTextField *errorLabel;
@property (strong) IBOutlet NSTextField *messageLabel;
@property (strong) IBOutlet NSImageView *appIcon;

@end

@implementation NCOpsHaltReasonDialog
{
    NSString* m_Message;
    NSString* m_Path;
    NSString* m_Error;
    int m_ErrorNo;
}

@synthesize message = m_Message;
@synthesize path = m_Path;
@synthesize error = m_Error;

- (instancetype)init
{
    self = [super initWithWindowNibName:@"HaltReasonDialog"];
    if( self ) {
        m_ErrorNo = VFSError::Ok;
    
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

- (IBAction)onClose:(id)[[maybe_unused]]_sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void) setErrorNo:(int)errorNo
{
    self.error = VFSError::ToNSError(errorNo).localizedDescription;
}

- (int) errorNo
{
    return m_ErrorNo;
}

@end

@interface NCOpsHaltReasonDialogWindow : NSWindow
@end

@implementation NCOpsHaltReasonDialogWindow
- (void)cancelOperation:(id)[[maybe_unused]]_sender
{
    [self.sheetParent endSheet:self returnCode:NSModalResponseCancel];
}
@end

