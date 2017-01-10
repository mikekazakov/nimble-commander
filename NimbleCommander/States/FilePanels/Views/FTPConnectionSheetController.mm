//
//  FTPConnectionSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 17.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/NetworkConnectionsManager.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "FTPConnectionSheetController.h"

@implementation FTPConnectionSheetController
{
    vector<NetworkConnectionsManager::Connection> m_Connections;
    optional<NetworkConnectionsManager::Connection> m_Original;
    NetworkConnectionsManager::FTPConnection m_Connection;
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    m_Connections = NetworkConnectionsManager::Instance().FTPConnectionsByMRU();
    
    if( !m_Connections.empty() ) {
        self.saved.autoenablesItems = false;
        
        NSMenuItem *pref = [[NSMenuItem alloc] init];
        pref.title = NSLocalizedString(@"Recent Servers", "Menu item title, disabled - only as separator");
        pref.enabled = false;
        [self.saved.menu addItem:pref];
        
        for( auto &i: m_Connections ) {
            NSMenuItem *it = [NSMenuItem new];
            auto title = NetworkConnectionsManager::Instance().TitleForConnection(i);
            it.title = [NSString stringWithUTF8StdString:title];
            [self.saved.menu addItem:it];
        }
        
        [self.saved.menu addItem:NSMenuItem.separatorItem];
        [self.saved addItemWithTitle:NSLocalizedString(@"Clear Recent Servers...", "Menu item titile for recents clearing action")];
    }
    
    GoogleAnalytics::Instance().PostScreenView("FTP Connection");
}

- (IBAction)OnSaved:(id)sender
{
    long ind = self.saved.indexOfSelectedItem;
    if(ind == self.saved.numberOfItems - 1) {
        [self ClearRecentServers];
        return;
    }
        
    ind = ind - 2;
    if(ind < 0 || ind >= m_Connections.size())
        return;
    
    auto conn = m_Connections[ind];
    [self fillInfoFromStoredConnection:conn];
}

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
    
    string password;
    if( NetworkConnectionsManager::Instance().GetPassword(_conn, password) )
        self.password = [NSString stringWithUTF8StdString:password];
    else
        self.password = @"";
}

- (void) ClearRecentServers
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure you want to clear the list of recent servers?", "Asking user for confirmation for clearing recent connections");
    alert.informativeText = NSLocalizedString(@"You can’t undo this action.", "Informing user that action can't be reverted");
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    if(alert.runModal == NSAlertFirstButtonReturn) {
        
        for( auto &i: m_Connections )
            NetworkConnectionsManager::Instance().RemoveConnection(i);
        m_Connections.clear();
        
        [self.saved selectItemAtIndex:0];
        while( self.saved.numberOfItems > 1 )
            [self.saved removeItemAtIndex:self.saved.numberOfItems - 1];
    }
}

- (IBAction)OnConnect:(id)sender
{
    if( m_Original)
        m_Connection.uuid = m_Original->Uuid();
    else
        m_Connection.uuid = NetworkConnectionsManager::Instance().MakeUUID();
    
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

@end
