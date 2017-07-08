#include "CreateHardlinkDialog.h"

@interface NCOpsCreateHardlinkDialog ()

@property (strong) IBOutlet NSTextField *Text;
@property (strong) IBOutlet NSTextField *LinkName;

- (IBAction)OnCreate:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end


@implementation NCOpsCreateHardlinkDialog
{
    string m_SourceName;
    string m_Result;
}

@synthesize result = m_Result;

- (instancetype)initWithSourceName:(const string&)_src
{
    if( self = [super initWithWindowNibName:@"CreateHardlinkDialog"] ) {
        m_SourceName = _src;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
//    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    [self.Text setStringValue:[NSString stringWithFormat:@"Create a hardlink of \'%@\' to:", [NSString stringWithUTF8StdString:m_SourceName]]];
    [self.window makeFirstResponder:self.LinkName];
//    GA().PostScreenView("Hardlink Create");
}

- (IBAction)OnCreate:(id)sender
{
    if( self.LinkName.stringValue )
        m_Result = self.LinkName.stringValue.fileSystemRepresentationSafe;
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];    
}

- (IBAction)OnCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

//- (void)showSheetFor:(NSWindow *)_window
//      withSourceName:(const string&)_src
//   completionHandler:(void (^)(NSModalResponse returnCode))_handler
//{
//    m_SourceName = _src;
//    [super beginSheetForWindow:_window completionHandler:_handler];
//}

@end
