// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "WebDAVConnectionSheetController.h"
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <Utility/CocoaAppearanceManager.h>
#include <boost/algorithm/string.hpp>
#include <Utility/StringExtras.h>

@interface WebDAVConnectionSheetController()
@property (nonatomic) bool isValid;
@property (nonatomic) IBOutlet NSTextField *titleTextField;
@property (nonatomic) IBOutlet NSPopUpButton *protocolPopup;
@property (nonatomic) IBOutlet NSTextField *serverTextField;
@property (nonatomic) IBOutlet NSTextField *basePathTextField;
@property (nonatomic) IBOutlet NSTextField *usernameTextField;
@property (nonatomic) IBOutlet NSSecureTextField *passwordTextField;
@property (nonatomic) IBOutlet NSTextField *remotePortTextField;
@property (nonatomic) IBOutlet NSButton *connectButton;

@end

@implementation WebDAVConnectionSheetController
{
    std::optional<NetworkConnectionsManager::Connection> m_Original;
    std::optional<std::string> m_Password;
    NetworkConnectionsManager::WebDAV m_Connection;
}

- (id) init
{
    self = [super init];
    if(self) {
        self.isValid = false;
    }
    return self;
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    nc::utility::CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);

    if( self.setupMode )
        self.connectButton.title = self.connectButton.alternateTitle;

    GA().PostScreenView("WebDAV Connection");
    
    if( m_Original ) {
        auto &c = m_Original->Get<NetworkConnectionsManager::WebDAV>();
        self.titleTextField.stringValue = [NSString stringWithUTF8StdString:c.title];
        self.serverTextField.stringValue = [NSString stringWithUTF8StdString:c.host];
        self.basePathTextField.stringValue = [NSString stringWithUTF8StdString:c.path];
        self.usernameTextField.stringValue = [NSString stringWithUTF8StdString:c.user];
        [self.protocolPopup selectItemWithTag:(int)c.https];
        if( c.port > 0 )
            self.remotePortTextField.stringValue = [NSString stringWithFormat:@"%i", c.port];
    }
    
    if( m_Password )
        self.passwordTextField.stringValue = [NSString stringWithUTF8StdString:*m_Password];
    
    [self validate];    
}

- (void)setConnection:(NetworkConnectionsManager::Connection)connection
{
    m_Original = connection;
}

- (NetworkConnectionsManager::Connection)connection
{
    return NetworkConnectionsManager::Connection( m_Connection );
}

- (void)setPassword:(std::string)_password
{
    m_Password = _password;
}

static const char *SafeStr( const char *_s )
{
    return _s ? _s : "";
}

- (std::string)password
{
    return m_Password ? *m_Password : "";
}

static std::string TrimSlashes(std::string _str)
{
    using namespace boost;
    trim_left_if(_str, is_any_of("/"));
    trim_right_if(_str, is_any_of("/"));
    return _str;
}

- (IBAction)onConnect:(id)[[maybe_unused]]_sender
{
    if( m_Original)
        m_Connection.uuid = m_Original->Uuid();
    else
        m_Connection.uuid =  NetworkConnectionsManager::MakeUUID();
    
    
    m_Connection.title = SafeStr(self.titleTextField.stringValue.UTF8String);
    m_Connection.host = SafeStr(self.serverTextField.stringValue.UTF8String);
    m_Connection.path = TrimSlashes(SafeStr(self.basePathTextField.stringValue.UTF8String));
    m_Connection.user = SafeStr(self.usernameTextField.stringValue.UTF8String);
    m_Connection.https = self.protocolPopup.selectedTag == 1;
    m_Connection.port = 0;
    if( self.remotePortTextField.intValue != 0 )
        m_Connection.port = self.remotePortTextField.intValue;
    
    m_Password = std::string(SafeStr(self.passwordTextField.stringValue.UTF8String));
    
    [self endSheet:NSModalResponseOK];
}

- (IBAction)onCancel:(id)[[maybe_unused]]_sender
{
    [self endSheet:NSModalResponseCancel];
}

- (void)controlTextDidChange:(NSNotification *)[[maybe_unused]]_obj
{
    [self validate];
}

- (void)validate
{
    self.isValid = self.validateServer && self.validatePort;
}

- (bool) validateServer
{
    const auto v = self.serverTextField.stringValue;
    return v != nil && v.length > 0;
}

- (bool)validatePort
{
    return !self.remotePortTextField.stringValue ||
        (self.remotePortTextField.stringValue.intValue >= 0 &&
         self.remotePortTextField.stringValue.intValue < 65'536);
}

@end
