#include "DirectoryCreationDialog.h"

@interface NCOpsDirectoryCreationDialog()

@property (strong) IBOutlet NSTextField *TextField;
@property (strong) IBOutlet NSButton *CreateButton;
@property bool isValid;
@end


@implementation NCOpsDirectoryCreationDialog
{
    string m_Result;
}

@synthesize result = m_Result;

- (instancetype)init
{
    self = [super initWithWindowNibName:@"DirectoryCreationDialog"];
    if( self ) {
        self.isValid = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    [self.window makeFirstResponder:self.TextField];
}

- (IBAction)OnCreate:(id)sender
{
    if( !self.TextField.stringValue || !self.TextField.stringValue.length )
        return;
    
    if( auto p = self.TextField.stringValue.fileSystemRepresentation )
        m_Result = p;
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == self.TextField )
        [self validate];
}

- (void)validate
{
    const auto v = self.TextField.stringValue;
    self.isValid = v && v.length > 0;
}

@end