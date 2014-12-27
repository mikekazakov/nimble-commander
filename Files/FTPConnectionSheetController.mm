//
//  FTPConnectionSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 17.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "FTPConnectionSheetController.h"
#import "SavedNetworkConnectionsManager.h"
#import "Common.h"

@implementation FTPConnectionSheetController
{
    vector<shared_ptr<SavedNetworkConnectionsManager::FTPConnection>> m_SavedConnections;
}

- (void) windowDidLoad
{
    m_SavedConnections = SavedNetworkConnectionsManager::Instance().GetFTPConnections();
    
    if(!m_SavedConnections.empty()) {
        self.saved.autoenablesItems = false;
        
        NSMenuItem *pref = [[NSMenuItem alloc] init];
        pref.title = @"Recent Servers";
        pref.enabled = false;
        [self.saved.menu addItem:pref];
        
        for(auto &i: m_SavedConnections)
            [self.saved addItemWithTitle:[NSString stringWithUTF8StdString:i->host]];
        
        [self.saved.menu addItem:NSMenuItem.separatorItem];
        [self.saved addItemWithTitle:@"Clear Recent Servers..."];
    }
}

- (IBAction)OnSaved:(id)sender
{
    long ind = self.saved.indexOfSelectedItem;
    if(ind == self.saved.numberOfItems - 1) {
        [self ClearRecentServers];
        return;
    }
        
    ind = ind - 2;
    if(ind < 0 || ind >= m_SavedConnections.size())
        return;
    
    auto conn = m_SavedConnections[ind];
    self.server = [NSString stringWithUTF8StdString:conn->host];
    self.username = [NSString stringWithUTF8StdString:conn->user];
    self.path = [NSString stringWithUTF8StdString:conn->path];
    self.port = [NSString stringWithFormat:@"%li", conn->port];
    
    string password;
    if(SavedNetworkConnectionsManager::Instance().GetPassword(conn, password))
        self.password = [NSString stringWithUTF8StdString:password];
    else
        self.password = @"";
}

- (void) ClearRecentServers
{
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Are you sure you want to clear the list of recent servers?";
    alert.informativeText = @"You can't undo this action.";
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Cancel"];
    if(alert.runModal == NSAlertFirstButtonReturn) {
        SavedNetworkConnectionsManager::Instance().EraseAllFTPConnections();
        [self.saved selectItemAtIndex:0];
        while( self.saved.numberOfItems > 1 )
            [self.saved removeItemAtIndex:self.saved.numberOfItems - 1];

        
    }
}

- (IBAction)OnConnect:(id)sender
{
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

@end
