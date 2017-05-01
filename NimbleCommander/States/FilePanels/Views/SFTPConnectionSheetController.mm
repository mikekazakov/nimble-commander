//
//  SFTPConnectionSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 31/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/CommonPaths.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "SFTPConnectionSheetController.h"

//#include <NimbleCommander/Core/ConfigBackedNetworkConnectionsManager.h>
//static NetworkConnectionsManager &ConnectionsManager()
//{
//    return ConfigBackedNetworkConnectionsManager::Instance();
//}


static const auto g_SSHdir = CommonPaths::Home() + ".ssh/";

@interface SFTPConnectionSheetController()
@property (strong) NSString *title;
@property (strong) NSString *server;
@property (strong) NSString *username;
@property (strong) NSString *passwordEntered;
@property (strong) NSString *port;
@property (strong) NSString *keypath;
@property (strong) IBOutlet NSPopUpButton *saved;
- (IBAction)OnSaved:(id)sender;
- (IBAction)OnConnect:(id)sender;
- (IBAction)OnClose:(id)sender;
- (IBAction)OnChooseKey:(id)sender;
- (void)fillInfoFromStoredConnection:(NetworkConnectionsManager::Connection)_conn;
@property (readonly, nonatomic) NetworkConnectionsManager::Connection result;
@end


@implementation SFTPConnectionSheetController
{
//    vector<NetworkConnectionsManager::Connection> m_Connections;
    optional<NetworkConnectionsManager::Connection> m_Original;
    NetworkConnectionsManager::SFTP m_Connection;
}

- (id) init
{
    self = [super init];
    if(self) {
//        m_Connections = ConnectionsManager().SFTPConnectionsByMRU();
        
        string rsa_path = g_SSHdir + "id_rsa";
        string dsa_path = g_SSHdir + "id_dsa";
        
        if( access(rsa_path.c_str(), R_OK) == 0 )
            self.keypath = [NSString stringWithUTF8StdString:rsa_path];
        else if( access(dsa_path.c_str(), R_OK) == 0 )
            self.keypath = [NSString stringWithUTF8StdString:dsa_path];
    }
    return self;
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);

//    if(!m_Connections.empty()) {
//        self.saved.autoenablesItems = false;
//        
//        NSMenuItem *pref = [[NSMenuItem alloc] init];
//        pref.title = NSLocalizedString(@"Recent Servers", "Menu item title, disabled - only as separator");
//        pref.enabled = false;
//        [self.saved.menu addItem:pref];
//        
//        for(auto &i: m_Connections) {
//            NSMenuItem *it = [NSMenuItem new];
//            auto title = ConnectionsManager().TitleForConnection(i);
//            it.title = [NSString stringWithUTF8StdString:title];
//            [self.saved.menu addItem:it];
//        }
//        
//        [self.saved.menu addItem:NSMenuItem.separatorItem];
//        [self.saved addItemWithTitle:NSLocalizedString(@"Clear Recent Servers...", "Menu item titile for recents clearing action")];
//    }
    
    GA().PostScreenView("SFTP Connection");
}

- (IBAction)OnSaved:(id)sender
{
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
}

- (void)fillInfoFromStoredConnection:(NetworkConnectionsManager::Connection)_conn
{
    [self window];

    m_Original = _conn;
    auto &c = m_Original->Get<NetworkConnectionsManager::SFTP>();
    
    self.title = [NSString stringWithUTF8StdString:c.title];
    self.server = [NSString stringWithUTF8StdString:c.host];
    self.username = [NSString stringWithUTF8StdString:c.user];
    self.keypath = [NSString stringWithUTF8StdString:c.keypath];
    self.port = [NSString stringWithFormat:@"%li", c.port];
    
//    string password;
//    if( ConnectionsManager().GetPassword(_conn, password) )
//        self.passwordEntered = [NSString stringWithUTF8StdString:password];
//    else
//        self.passwordEntered = @"";
}

- (void) ClearRecentServers
{
//    Alert *alert = [[Alert alloc] init];
//    alert.messageText = NSLocalizedString(@"Are you sure you want to clear the list of recent servers?", "Asking user if he want to clear recent connections");
//    alert.informativeText = NSLocalizedString(@"You can’t undo this action.", "Informating user that action can't be reverted");
//    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
//    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
//    if(alert.runModal == NSAlertFirstButtonReturn) {
//        for( auto &i: m_Connections )
//            ConnectionsManager().RemoveConnection(i);
//        m_Connections.clear();
//        [self.saved selectItemAtIndex:0];
//        while( self.saved.numberOfItems > 1 )
//            [self.saved removeItemAtIndex:self.saved.numberOfItems - 1];
//    }
}

- (IBAction)OnConnect:(id)sender
{
    if( m_Original)
        m_Connection.uuid = m_Original->Uuid();
    else
        m_Connection.uuid =  NetworkConnectionsManager::MakeUUID();
    
    m_Connection.title = self.title.UTF8String ? self.title.UTF8String : "";
    m_Connection.host = self.server.UTF8String ? self.server.UTF8String : "";
    m_Connection.user = self.username ? self.username.UTF8String : "";
    m_Connection.keypath = self.keypath ? self.keypath.UTF8String : "";
    m_Connection.port = 22;
    if(self.port.intValue != 0)
        m_Connection.port = self.port.intValue;
    
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnChooseKey:(id)sender
{
    auto initial_dir = access(g_SSHdir.c_str(), X_OK) == 0 ? g_SSHdir : CommonPaths::Home();
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = false;
    panel.canChooseFiles = true;
    panel.canChooseDirectories = false;
    panel.directoryURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithUTF8StdString:initial_dir]
                                                isDirectory:true];
    [panel beginSheetModalForWindow:self.window
                  completionHandler:^(NSInteger result){
                      if(result == NSFileHandlingPanelOKButton)
                          self.keypath = panel.URL.path;
                  }];
}

//@property (readonly, nonatomic) NetworkConnectionsManager::Connection result;
- (NetworkConnectionsManager::Connection) result
{
    return NetworkConnectionsManager::Connection( m_Connection );
}

//@property (nonatomic) NetworkConnectionsManager::Connection connection;

- (void)setConnection:(NetworkConnectionsManager::Connection)connection
{
    [self fillInfoFromStoredConnection:connection];
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

@end
