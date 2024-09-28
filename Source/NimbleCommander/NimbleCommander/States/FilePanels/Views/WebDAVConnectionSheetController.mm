// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WebDAVConnectionSheetController.h"
#include <Utility/StringExtras.h>
#include <Base/algo.h>

@interface WebDAVConnectionSheetController ()
@property(nonatomic) bool isValid;
@property(nonatomic) IBOutlet NSTextField *titleTextField;
@property(nonatomic) IBOutlet NSPopUpButton *protocolPopup;
@property(nonatomic) IBOutlet NSTextField *serverTextField;
@property(nonatomic) IBOutlet NSTextField *basePathTextField;
@property(nonatomic) IBOutlet NSTextField *usernameTextField;
@property(nonatomic) IBOutlet NSSecureTextField *passwordTextField;
@property(nonatomic) IBOutlet NSTextField *remotePortTextField;
@property(nonatomic) IBOutlet NSButton *connectButton;

@end

@implementation WebDAVConnectionSheetController {
    std::optional<nc::panel::NetworkConnectionsManager::Connection> m_Original;
    std::optional<std::string> m_Password;
    nc::panel::NetworkConnectionsManager::WebDAV m_Connection;
}
@synthesize setupMode;
@synthesize isValid;
@synthesize titleTextField;
@synthesize protocolPopup;
@synthesize serverTextField;
@synthesize basePathTextField;
@synthesize usernameTextField;
@synthesize passwordTextField;
@synthesize remotePortTextField;
@synthesize connectButton;

- (id)init
{
    self = [super init];
    if( self ) {
        self.isValid = false;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

    if( self.setupMode )
        self.connectButton.title = self.connectButton.alternateTitle;

    if( m_Original ) {
        auto &c = m_Original->Get<nc::panel::NetworkConnectionsManager::WebDAV>();
        self.titleTextField.stringValue = [NSString stringWithUTF8StdString:c.title];
        self.serverTextField.stringValue = [NSString stringWithUTF8StdString:c.host];
        self.basePathTextField.stringValue = [NSString stringWithUTF8StdString:c.path];
        self.usernameTextField.stringValue = [NSString stringWithUTF8StdString:c.user];
        [self.protocolPopup selectItemWithTag:static_cast<int>(c.https)];
        if( c.port > 0 )
            self.remotePortTextField.stringValue = [NSString stringWithFormat:@"%i", c.port];
    }

    if( m_Password )
        self.passwordTextField.stringValue = [NSString stringWithUTF8StdString:*m_Password];

    [self validate];
}

- (void)setConnection:(nc::panel::NetworkConnectionsManager::Connection)connection
{
    m_Original = connection;
}

- (nc::panel::NetworkConnectionsManager::Connection)connection
{
    return nc::panel::NetworkConnectionsManager::Connection(m_Connection);
}

- (void)setPassword:(std::string)_password
{
    m_Password = _password;
}

static const char *SafeStr(const char *_s)
{
    return _s ? _s : "";
}

- (std::string)password
{
    return m_Password ? *m_Password : "";
}

- (IBAction)onConnect:(id) [[maybe_unused]] _sender
{
    if( m_Original )
        m_Connection.uuid = m_Original->Uuid();
    else
        m_Connection.uuid = nc::panel::NetworkConnectionsManager::MakeUUID();

    m_Connection.title = SafeStr(self.titleTextField.stringValue.UTF8String);
    m_Connection.host = SafeStr(self.serverTextField.stringValue.UTF8String);
    m_Connection.path = std::string{nc::base::Trim(SafeStr(self.basePathTextField.stringValue.UTF8String), '/')};
    m_Connection.user = SafeStr(self.usernameTextField.stringValue.UTF8String);
    m_Connection.https = self.protocolPopup.selectedTag == 1;
    m_Connection.port = 0;
    if( self.remotePortTextField.intValue != 0 )
        m_Connection.port = self.remotePortTextField.intValue;

    m_Password = std::string(SafeStr(self.passwordTextField.stringValue.UTF8String));

    [self endSheet:NSModalResponseOK];
}

- (IBAction)onCancel:(id) [[maybe_unused]] _sender
{
    [self endSheet:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *) [[maybe_unused]] _obj
{
    [self validate];
}

- (void)validate
{
    self.isValid = self.validateServer && self.validatePort;
}

- (bool)validateServer
{
    const auto v = self.serverTextField.stringValue;
    return v != nil && v.length > 0;
}

- (bool)validatePort
{
    return !self.remotePortTextField.stringValue || (self.remotePortTextField.stringValue.intValue >= 0 &&
                                                     self.remotePortTextField.stringValue.intValue < 65'536);
}

@end
