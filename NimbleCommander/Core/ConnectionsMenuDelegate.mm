//
//  ConnectionsMenuDelegate.m
//  Files
//
//  Created by Michael G. Kazakov on 28/12/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "ConnectionsMenuDelegate.h"
#include <NimbleCommander/States/FilePanels/PanelController.h>

@interface ConnectionsMenuDelegateInfoWrapper()
- (id) initWithConnection:(const NetworkConnectionsManager::Connection &)_conn;
@end

@implementation ConnectionsMenuDelegateInfoWrapper
{
    optional<NetworkConnectionsManager::Connection> m_Connection;
}

- (id) initWithConnection:(const NetworkConnectionsManager::Connection &)_conn
{
    self = [super init];
    if(self) {
        m_Connection = _conn;
    }
    return self;
}

- (NetworkConnectionsManager::Connection) object
{
    return *m_Connection;
}
@end

@implementation ConnectionsMenuDelegate
{
    vector<NetworkConnectionsManager::Connection> m_Connections;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu*)menu
{
    m_Connections = NetworkConnectionsManager::Instance().AllConnectionsByMRU();
    
    if(m_Connections.empty())
        return 2;
    else
        return m_Connections.size()*3 + 4;
}

- (BOOL)menu:(NSMenu*)menu updateItem:(NSMenuItem*)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    if(index == 2) {
        [menu removeItemAtIndex:index];
        [menu insertItem:NSMenuItem.separatorItem atIndex:index];
    }
    else if(index == 3) {
        [menu removeItemAtIndex:index];
        [menu insertItem:[self.recentConnectionsMenuItem copy] atIndex:index];
    }
    else if(index >= 4) {
        auto menu_ind = index - 4;
        auto conn_num = menu_ind / 3;
        if(conn_num >= m_Connections.size())
            return true;
        auto &c = m_Connections.at(conn_num);

        item.indentationLevel = 1;
        item.title = [NSString stringWithUTF8StdString:NetworkConnectionsManager::Instance().TitleForConnection(c)];
        item.representedObject = [[ConnectionsMenuDelegateInfoWrapper alloc] initWithConnection:c];

        //clang gone mad, so mute nonsence warning
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
        if(menu_ind % 3 == 0) {
            item.action = @selector(OnGoToSavedConnectionItem:);
        }
        else if(menu_ind % 3 == 1) {
            item.title = [NSString stringWithFormat:@"♻ %@", item.title];
            item.keyEquivalentModifierMask = NSAlternateKeyMask;
            item.alternate = true;
            item.action = @selector(OnDeleteSavedConnectionItem:);
        }
        else {
            item.title = [NSString stringWithFormat:@"%@...", item.title];
            item.keyEquivalentModifierMask = NSShiftKeyMask;
            item.alternate = true;
            item.action = @selector(OnEditSavedConnectionItem:);
        }
#pragma clang diagnostic pop
    }
    return true;
}

@end
