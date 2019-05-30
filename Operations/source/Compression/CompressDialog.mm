// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "CompressDialog.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>

@interface NCOpsCompressDialog ()
@property (weak) IBOutlet NSButton *compressButton;
@property (weak) IBOutlet NSButton *cancelButton;
@property (weak) IBOutlet NSButton *protectWithPasswordCheckbox;
@property (weak) IBOutlet NSSecureTextField *passwordTextField;
@property (weak) IBOutlet NSTextField *destinationTextField;
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
        [self validate];
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
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

- (IBAction)onCompress:(id)sender
{
    m_FinalDestination = self.destinationString.decomposedStringWithCanonicalMapping.UTF8String;
    
    if( self.protectWithPassword )
        m_FinalPassword = self.passwordString.UTF8String;
    
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseOK];
}

- (IBAction)onCancel:(id)sender
{
    [self.window.sheetParent endSheet:self.window returnCode:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    if( objc_cast<NSTextField>(notification.object) == self.destinationTextField ||
       objc_cast<NSTextField>(notification.object) == self.passwordTextField )
        [self validate];
}

- (IBAction)onProtectWithPassword:(id)sender
{
    [self validate];
}

@end
