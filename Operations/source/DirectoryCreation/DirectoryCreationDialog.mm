#include "DirectoryCreationDialog.h"

@interface NCOpsDirectoryCreationDialog()

- (IBAction)OnCreate:(id)sender;
- (IBAction)OnCancel:(id)sender;
@property (strong) IBOutlet NSTextField *TextField;
@property (strong) IBOutlet NSButton *CreateButton;

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

@end
