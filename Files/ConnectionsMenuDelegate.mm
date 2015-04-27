//
//  ConnectionsMenuDelegate.m
//  Files
//
//  Created by Michael G. Kazakov on 28/12/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "ConnectionsMenuDelegate.h"
#import "Common.h"
#import "PanelController.h"

@interface ConnectionsMenuDelegateInfoWrapper()
- (id) initWithConnection:(const shared_ptr<SavedNetworkConnectionsManager::AbstractConnection> &)_conn;
@end

@implementation ConnectionsMenuDelegateInfoWrapper
{
    shared_ptr<SavedNetworkConnectionsManager::AbstractConnection> m_Connection;
}

- (id) initWithConnection:(const shared_ptr<SavedNetworkConnectionsManager::AbstractConnection> &)_conn
{
    self = [super init];
    if(self) {
        m_Connection = _conn;
    }
    return self;
}

- (shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>) object
{
    return m_Connection;
}
@end

@implementation ConnectionsMenuDelegate
{
    vector<shared_ptr<SavedNetworkConnectionsManager::AbstractConnection>> m_Connections;
}

- (NSInteger)numberOfItemsInMenu:(NSMenu*)menu
{
    m_Connections = SavedNetworkConnectionsManager::Instance().Connections();
    
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
        item.title = [NSString stringWithUTF8StdString:SavedNetworkConnectionsManager::Instance().TitleForConnection(c)];
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
