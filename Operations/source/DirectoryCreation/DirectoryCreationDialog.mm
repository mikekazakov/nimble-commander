// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "DirectoryCreationDialog.h"

@interface NCOpsDirectoryCreationDialog()

@property (strong) IBOutlet NSTextField *TextField;
@property (strong) IBOutlet NSButton *CreateButton;
@property bool isValid;
@end


@implementation NCOpsDirectoryCreationDialog
{
    string m_Result;
    string m_Suggestion;
    function<bool(const string&)> m_ValidationCallback;
}

@synthesize result = m_Result;
@synthesize suggestion = m_Suggestion;
@synthesize validationCallback = m_ValidationCallback;

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
    if( auto v = [NSString stringWithUTF8StdString:m_Suggestion] )
        self.TextField.stringValue = v;
    [self.window makeFirstResponder:self.TextField];
    [self validate];
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
    if( !v  ) {
        self.isValid = false;
    }
    else {
        if( m_ValidationCallback )
            self.isValid = m_ValidationCallback( v.UTF8String );
        else
            self.isValid = v.length > 0;
    }
}

@end
