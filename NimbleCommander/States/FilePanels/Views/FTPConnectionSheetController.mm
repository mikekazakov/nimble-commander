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
@end

@implementation FTPConnectionSheetController
{
    optional<NetworkConnectionsManager::Connection> m_Original;
    NetworkConnectionsManager::FTPConnection m_Connection;
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    self.passwordEntered = @"";
    
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    
    
//    m_Connections = ConnectionsManager().FTPConnectionsByMRU();
    
//    if( !m_Connections.empty() ) {
//        self.saved.autoenablesItems = false;
        
//        NSMenuItem *pref = [[NSMenuItem alloc] init];
//        pref.title = NSLocalizedString(@"Recent Servers", "Menu item title, disabled - only as separator");
//        pref.enabled = false;
//        [self.saved.menu addItem:pref];
//        
//        for( auto &i: m_Connections ) {
//            NSMenuItem *it = [NSMenuItem new];
//            auto title = ConnectionsManager().TitleForConnection(i);
//            it.title = [NSString stringWithUTF8StdString:title];
//            [self.saved.menu addItem:it];
//        }
//        
//        [self.saved.menu addItem:NSMenuItem.separatorItem];
//        [self.saved addItemWithTitle:NSLocalizedString(@"Clear Recent Servers...", "Menu item titile for recents clearing action")];
//    }
    
    GA().PostScreenView("FTP Connection");
}

//- (IBAction)OnSaved:(id)sender
//{
//    long ind = self.saved.indexOfSelectedItem;
//    if(ind == self.saved.numberOfItems - 1) {
//        [self ClearRecentServers];
//        return;
//    }
//        
//    ind = ind - 2;
//    if(ind < 0 || ind >= m_Connections.size())
//        return;
//    
//    auto conn = m_Connections[ind];
//    [self fillInfoFromStoredConnection:conn];
//}

- (void)fillInfoFromStoredConnection:(NetworkConnectionsManager::Connection)_conn
{
    [self window];
    
    m_Original = _conn;
    auto &c = m_Original->Get<NetworkConnectionsManager::FTPConnection>();

    self.title = [NSString stringWithUTF8StdString:c.title];
    self.server = [NSString stringWithUTF8StdString:c.host];
    self.username = [NSString stringWithUTF8StdString:c.user];
    self.path = [NSString stringWithUTF8StdString:c.path];
    self.port = [NSString stringWithFormat:@"%li", c.port];
    
//    string password;
//    if( ConnectionsManager().GetPassword(_conn, password) )
//        self.passwordEntered = [NSString stringWithUTF8StdString:password];
//    else
//        self.passwordEntered = @"";
}

//- (void) ClearRecentServers
//{
//    Alert *alert = [[Alert alloc] init];
//    alert.messageText = NSLocalizedString(@"Are you sure you want to clear the list of recent servers?", "Asking user for confirmation for clearing recent connections");
//    alert.informativeText = NSLocalizedString(@"You can’t undo this action.", "Informing user that action can't be reverted");
//    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
//    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
//    if(alert.runModal == NSAlertFirstButtonReturn) {
//        
//        for( auto &i: m_Connections )
//            ConnectionsManager().RemoveConnection(i);
//        m_Connections.clear();
//        
//        [self.saved selectItemAtIndex:0];
//        while( self.saved.numberOfItems > 1 )
//            [self.saved removeItemAtIndex:self.saved.numberOfItems - 1];
//    }
//}

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
    [self fillInfoFromStoredConnection:connection];
}

- (NetworkConnectionsManager::Connection)connection
{
    return NetworkConnectionsManager::Connection( m_Connection );
}

- (void) setPassword:(string)password
{
//    m_Password = password;
    self.passwordEntered = [NSString stringWithUTF8StdString:password];
}

- (string)password
{
    return self.passwordEntered ? self.passwordEntered.UTF8String : "";
}

//@property (nonatomic) NetworkConnectionsManager::Connection connection;
//@property (nonatomic) string password;


@end
