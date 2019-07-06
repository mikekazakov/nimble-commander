// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CompressDialog.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include <Operations/FilenameTextControl.h>
#include "../Internal.h"

using namespace nc::ops;

@interface NCOpsCompressDialog ()
@property (weak) IBOutlet NSButton *compressButton;
@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSButton *protectWithPasswordCheckbox;
@property (weak) IBOutlet NSSecureTextField *passwordTextField;
@property (weak) IBOutlet NSTextField *destinationTextField;
@property (weak) IBOutlet NSTextField *destinationTitleTextField;
@property () bool protectWithPassword;
@property () bool validInput;
@property () NSString *destinationString;
@property () NSString *passwordString;

@end

@implementation NCOpsCompressDialog
{
    std::vector<VFSListingItem> m_SourceItems;    
    VFSHostPtr m_DestinationHost;
    std::string m_InitialDestination;
    std::string m_FinalDestination;
    std::string m_FinalPassword;
    std::shared_ptr<nc::ops::DirectoryPathAutoCompetion> m_AutoCompletion;
    NCFilepathAutoCompletionDelegate *m_AutoCompletionDelegate;
}

@synthesize destination = m_FinalDestination;
@synthesize password = m_FinalPassword;

- (instancetype) initWithItems:(const std::vector<VFSListingItem>&)_source_items
                destinationVFS:(const VFSHostPtr&)_destination_host
            initialDestination:(const std::string&)_initial_destination
{
    self = [super initWithWindowNibName:@"CompressDialog"];
    if( self ) {
        m_SourceItems = _source_items;
        m_DestinationHost = _destination_host;
        m_InitialDestination = _initial_destination;      
        self.protectWithPassword = false;
        self.destinationString = [NSString stringWithUTF8StdString:m_InitialDestination];
        self.validInput = false;
        m_AutoCompletion = 
            std::make_shared<nc::ops::DirectoryPathAutoCompletionImpl>(m_DestinationHost);
        m_AutoCompletionDelegate = [[NCFilepathAutoCompletionDelegate alloc] init];
        m_AutoCompletionDelegate.completion = m_AutoCompletion;
        m_AutoCompletionDelegate.isNativeVFS = m_DestinationHost->IsNativeFS();
        [self validate];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    const auto amount = (int)m_SourceItems.size();
    if( amount > 1 )
        self.destinationTitleTextField.stringValue =
        [NSString stringWithFormat:NSLocalizedString(@"Compress %@ items to:",
                                                     "Compress files sheet prompt, compressing many files"),
         [NSNumber numberWithInt:amount]];
    else
        self.destinationTitleTextField.stringValue =
        [NSString stringWithFormat:NSLocalizedString(@"Compress \u201c%@\u201d to:",
                                                     "Compress files sheet prompt, compressing single file"),
         m_SourceItems.front().FilenameNS()];
}

- (void)validate
{
    bool valid = true;
    if( self.destinationString.length == 0 )
        valid = false;
    if( self.protectWithPassword && self.passwordString.length == 0 )
        valid = false;
    self.validInput = valid;
}

- (IBAction)onCompress:(id)[[maybe_unused]]_sender
{
    m_FinalDestination = self.destinationString.decomposedStringWithCanonicalMapping.UTF8String;
    
    if( self.protectWithPassword )
        m_FinalPassword = self.passwordString.UTF8String;
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)onCancel:(id)[[maybe_unused]]_sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == self.destinationTextField ||
       objc_cast<NSTextField>(notification.object) == self.passwordTextField )
        [self validate];
}

- (IBAction)onProtectWithPassword:(id)[[maybe_unused]]_sender
{
    [self validate];
}

- (BOOL)control:(NSControl *)_control
       textView:(NSTextView *)_text_view
doCommandBySelector:(SEL)_command_selector
{
    if( _control == self.destinationTextField && _command_selector == @selector(complete:)) {
        return [m_AutoCompletionDelegate control:_control
                                 textView:_text_view
                      doCommandBySelector:_command_selector];
    }
    return false;
}

@end
