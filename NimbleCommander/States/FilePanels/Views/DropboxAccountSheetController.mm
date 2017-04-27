#include "DropboxAccountSheetController.h"

@interface DropboxAccountSheetController ()
@property (strong) IBOutlet NSTextField *accountField;
@property (strong) IBOutlet NSTextField *tokenField;

@end

@implementation DropboxAccountSheetController

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)onConnect:(id)sender
{
    [self endSheet:NSModalResponseOK];
}

- (IBAction)onClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)onRequestAccess:(id)sender
{

}

@end
