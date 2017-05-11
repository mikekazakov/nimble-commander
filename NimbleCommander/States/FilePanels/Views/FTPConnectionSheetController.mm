#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "FTPConnectionSheetController.h"

@interface FTPConnectionSheetController()
@property (strong) NSString *title;
@property (strong) NSString *server;
@property (strong) NSString *username;
@property (strong) NSString *passwordEntered;
@property (strong) NSString *path;
@property (strong) NSString *port;
@property (strong) IBOutlet NSButton *connectButton;
@property bool isValid;
@end

@implementation FTPConnectionSheetController
{
    optional<NetworkConnectionsManager::Connection> m_Original;
    NetworkConnectionsManager::FTP m_Connection;
}

- (instancetype)init
{
    self = [super init];
    if( self ) {
        self.isValid = false;
    }
    return self;
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    self.passwordEntered = @"";
    
    if( self.setupMode )
        self.connectButton.title = self.connectButton.alternateTitle;
    
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    
    GA().PostScreenView("FTP Connection");
    
    if( m_Original  ) {
        auto &c = m_Original->Get<NetworkConnectionsManager::FTP>();
        self.title = [NSString stringWithUTF8StdString:c.title];
        self.server = [NSString stringWithUTF8StdString:c.host];
        self.username = [NSString stringWithUTF8StdString:c.user];
        self.path = [NSString stringWithUTF8StdString:c.path];
        self.port = [NSString stringWithFormat:@"%li", c.port];
    }
    [self validate];
}

- (IBAction)OnConnect:(id)sender
{
    if( m_Original)
        m_Connection.uuid = m_Original->Uuid();
    else
        m_Connection.uuid = NetworkConnectionsManager::MakeUUID();
    
    m_Connection.title = self.title.UTF8String ? self.title.UTF8String : "";
    m_Connection.host = self.server.UTF8String ? self.server.UTF8String : "";
    m_Connection.user = self.username ? self.username.UTF8String : "";
    m_Connection.path = self.path ? self.path.UTF8String : "/";
    if(m_Connection.path.empty() || m_Connection.path[0] != '/')
        m_Connection.path = "/";
    m_Connection.port = 21;
    if(self.port.intValue != 0)
        m_Connection.port = self.port.intValue;
    
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (NetworkConnectionsManager::Connection) result
{
    return NetworkConnectionsManager::Connection( m_Connection );
}

- (void) setConnection:(NetworkConnectionsManager::Connection)connection
{
    m_Original = connection;
}

- (NetworkConnectionsManager::Connection)connection
{
    return NetworkConnectionsManager::Connection( m_Connection );
}

- (void) setPassword:(string)password
{
    self.passwordEntered = [NSString stringWithUTF8StdString:password];
}

- (string)password
{
    return self.passwordEntered ? self.passwordEntered.UTF8String : "";
}

- (bool)validateServer
{
    return self.server && self.server.length > 0;
}

- (void)validate
{
    const auto valid_server = [self validateServer];
    self.isValid = valid_server;
}

- (void)controlTextDidChange:(NSNotification *)obj
{
    [self validate];
}

@end
