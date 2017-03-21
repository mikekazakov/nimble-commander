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

- (void)menuNeedsUpdate:(NSMenu*)menu
{
    if( (menu.propertiesToUpdate & NSMenuPropertyItemTitle) == 0 )
        return; // we should update this menu only when it's shown, not by a key press
  
    // there's no "dirty" state for MRU, so need to fetch data on every access current state
    // and compare it with previously used. this is ugly, but it's much better than rebuilding whole
    // menu every time. Better approach would be making NetworkConnectionsManager observable.
    auto &ncm = NetworkConnectionsManager::Instance();
    auto connections = ncm.AllConnectionsByMRU();
    if( m_Connections != connections ) {
        m_Connections = move(connections);
    
        while( menu.numberOfItems > 4 )
            [menu removeItemAtIndex:menu.numberOfItems-1];
        
        self.recentConnectionsMenuItem.hidden = m_Connections.empty();
        
        for( auto &c: m_Connections ) {
            const auto title = [NSString stringWithUTF8StdString:ncm.TitleForConnection(c)];
            const auto o = [[ConnectionsMenuDelegateInfoWrapper alloc] initWithConnection:c];
            
            NSMenuItem *regular_item = [[NSMenuItem alloc] init];
            regular_item.indentationLevel = 1;
            regular_item.title = title;
            regular_item.representedObject = o;
            regular_item.action = @selector(OnGoToSavedConnectionItem:);
            [menu addItem:regular_item];
            
            NSMenuItem *delete_item = [[NSMenuItem alloc] init];
            delete_item.indentationLevel = 1;
            delete_item.title = [NSString stringWithFormat:@"♻ %@", title];
            delete_item.representedObject = o;
            delete_item.action = @selector(OnDeleteSavedConnectionItem:);
            delete_item.keyEquivalentModifierMask = NSAlternateKeyMask;
            delete_item.alternate = true;
            [menu addItem:delete_item];
            
            NSMenuItem *edit_item = [[NSMenuItem alloc] init];
            edit_item.indentationLevel = 1;
            edit_item.title = [NSString stringWithFormat:@"%@...", title];
            edit_item.representedObject = o;
            edit_item.action = @selector(OnEditSavedConnectionItem:);
            edit_item.keyEquivalentModifierMask = NSShiftKeyMask;
            edit_item.alternate = true;
            [menu addItem:edit_item];
        }
    }
}

@end
