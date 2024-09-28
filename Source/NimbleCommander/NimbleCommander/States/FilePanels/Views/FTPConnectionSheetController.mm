// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include <NimbleCommander/Core/Alert.h>
#include <Panel/NetworkConnectionsManager.h>
#include "FTPConnectionSheetController.h"
#include <Utility/StringExtras.h>

@interface FTPConnectionSheetController ()
@property(nonatomic) NSString *title;
@property(nonatomic) NSString *server;
@property(nonatomic) NSString *username;
@property(nonatomic) NSString *passwordEntered;
@property(nonatomic) NSString *path;
@property(nonatomic) NSString *port;
@property(nonatomic) IBOutlet NSButton *connectButton;
@property(nonatomic) BOOL active;
@property(nonatomic) bool isValid;
@end

@implementation FTPConnectionSheetController {
    std::optional<nc::panel::NetworkConnectionsManager::Connection> m_Original;
    nc::panel::NetworkConnectionsManager::FTP m_Connection;
}
@synthesize setupMode;
@synthesize title;
@synthesize server;
@synthesize username;
@synthesize passwordEntered;
@synthesize path;
@synthesize port;
@synthesize connectButton;
@synthesize active;
@synthesize isValid;

- (instancetype)init
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
    self.passwordEntered = @"";

    if( self.setupMode )
        self.connectButton.title = self.connectButton.alternateTitle;

    if( m_Original ) {
        auto &c = m_Original->Get<nc::panel::NetworkConnectionsManager::FTP>();
        self.title = [NSString stringWithUTF8StdString:c.title];
        self.server = [NSString stringWithUTF8StdString:c.host];
        self.username = [NSString stringWithUTF8StdString:c.user];
        self.path = [NSString stringWithUTF8StdString:c.path];
        self.port = [NSString stringWithFormat:@"%li", c.port];
        self.active = c.active;
    }
    [self validate];
}

- (IBAction)OnConnect:(id) [[maybe_unused]] _sender
{
    if( m_Original )
        m_Connection.uuid = m_Original->Uuid();
    else
        m_Connection.uuid = nc::panel::NetworkConnectionsManager::MakeUUID();

    m_Connection.title = self.title.UTF8String ? self.title.UTF8String : "";
    m_Connection.host = self.server.UTF8String ? self.server.UTF8String : "";
    m_Connection.user = self.username ? self.username.UTF8String : "";
    m_Connection.path = self.path ? self.path.UTF8String : "/";
    if( m_Connection.path.empty() || m_Connection.path[0] != '/' )
        m_Connection.path = "/";
    m_Connection.port = 21;
    if( self.port.intValue != 0 )
        m_Connection.port = self.port.intValue;
    m_Connection.active = self.active;

    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnClose:(id) [[maybe_unused]] _sender
{
    [self endSheet:NSModalResponseCancel];
}

- (nc::panel::NetworkConnectionsManager::Connection)result
{
    return nc::panel::NetworkConnectionsManager::Connection(m_Connection);
}

- (void)setConnection:(nc::panel::NetworkConnectionsManager::Connection)connection
{
    m_Original = connection;
}

- (nc::panel::NetworkConnectionsManager::Connection)connection
{
    return nc::panel::NetworkConnectionsManager::Connection(m_Connection);
}

- (void)setPassword:(std::string)password
{
    self.passwordEntered = [NSString stringWithUTF8StdString:password];
}

- (std::string)password
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

- (void)controlTextDidChange:(NSNotification *) [[maybe_unused]] _obj
{
    [self validate];
}

@end
