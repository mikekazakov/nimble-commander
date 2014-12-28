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

static NSString *TitleForConnection( SavedNetworkConnectionsManager::AbstractConnection &_conn )
{
    if(auto ftp = dynamic_cast<SavedNetworkConnectionsManager::FTPConnection*>(&_conn)) {
        if(!ftp->user.empty())
          return [NSString stringWithFormat:@"ftp://%@@%@",
                  [NSString stringWithUTF8StdString:ftp->user],
                  [NSString stringWithUTF8StdString:ftp->host]];
        else
            return [NSString stringWithFormat:@"ftp://%@",
                    [NSString stringWithUTF8StdString:ftp->host]];
    }
    if(auto ftp = dynamic_cast<SavedNetworkConnectionsManager::SFTPConnection*>(&_conn)) {
        return [NSString stringWithFormat:@"sftp://%@@%@",
                [NSString stringWithUTF8StdString:ftp->user],
                [NSString stringWithUTF8StdString:ftp->host]];
    }
    return @"";
}

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
        return m_Connections.size() + 4;
}

- (BOOL)menu:(NSMenu*)menu updateItem:(NSMenuItem*)item atIndex:(NSInteger)index shouldCancel:(BOOL)shouldCancel
{
    if(index == 2) {
        [menu removeItemAtIndex:index];
        [menu insertItem:NSMenuItem.separatorItem atIndex:index];
    }
    else if(index == 3) {
        item.title = @"Recent Connections";
    }
    else if(index >= 4) {
        auto conn_num = index - 4;
        if(conn_num >= m_Connections.size())
            return true;
        auto &c = m_Connections.at(conn_num);
        item.title = TitleForConnection(*c);
        item.indentationLevel = 1;
        item.representedObject = [[ConnectionsMenuDelegateInfoWrapper alloc] initWithConnection:c];
//clang gone mad, so mute nonsence warning
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wselector"
        item.action = @selector(OnGoToSavedConnectionItem:);
#pragma clang diagnostic pop
    }
    
    return true;
}

@end
