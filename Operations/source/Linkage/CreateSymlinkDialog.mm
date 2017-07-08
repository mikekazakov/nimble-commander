#include "CreateSymlinkDialog.h"

@interface NCOpsCreateSymlinkDialog()

@property (strong) IBOutlet NSTextField *SourcePath;
@property (strong) IBOutlet NSTextField *LinkPath;

- (IBAction)OnCreate:(id)sender;
- (IBAction)OnCancel:(id)sender;

@end

@implementation NCOpsCreateSymlinkDialog
{
    string m_SrcPath;
    string m_LinkPath;
}

@synthesize sourcePath = m_SrcPath;
@synthesize linkPath = m_LinkPath;

- (instancetype) initWithSourcePath:(const string&)_src_path andDestPath:(const string&)_link_path
{
    if( self = [super initWithWindowNibName:@"CreateSymlinkDialog"] ) {
        m_SrcPath  = _src_path;
        m_LinkPath = _link_path;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    self.SourcePath.stringValue = [NSString stringWithUTF8StdString:m_SrcPath];
    self.LinkPath.stringValue = [NSString stringWithUTF8StdString:m_LinkPath];
    
    [self.window makeFirstResponder:self.LinkPath];
    const auto r = [self.LinkPath.stringValue rangeOfCharacterFromSet:
                    [NSCharacterSet characterSetWithCharactersInString:@"/"]
                                               options:NSBackwardsSearch];
    if( r.location != NSNotFound )
        self.LinkPath.currentEditor.selectedRange = NSMakeRange(r.location+1,
                                                                self.LinkPath.stringValue.length);
}

- (IBAction)OnCreate:(id)sender
{
    m_SrcPath = self.SourcePath.stringValue.fileSystemRepresentationSafe;
    m_LinkPath = self.LinkPath.stringValue.fileSystemRepresentationSafe;
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)OnCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

@end
