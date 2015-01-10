//
//  SFTPConnectionSheetController.m
//  Files
//
//  Created by Michael G. Kazakov on 31/08/14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#import "SFTPConnectionSheetController.h"
#import "common_paths.h"
#import "Common.h"
#import "SavedNetworkConnectionsManager.h"

static const auto g_SSHdir = CommonPaths::Get(CommonPaths::Home) + ".ssh/";

@implementation SFTPConnectionSheetController
{
    vector<shared_ptr<SavedNetworkConnectionsManager::SFTPConnection>> m_SavedConnections;
}

- (id) init
{
    self = [super init];
    if(self) {
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
    m_SavedConnections = SavedNetworkConnectionsManager::Instance().SFTPConnections();
    
    if(!m_SavedConnections.empty()) {
        self.saved.autoenablesItems = false;
        
        NSMenuItem *pref = [[NSMenuItem alloc] init];
        pref.title = NSLocalizedString(@"Recent Servers", "Menu item title, disabled - only as separator");
        pref.enabled = false;
        [self.saved.menu addItem:pref];
        
        for(auto &i: m_SavedConnections)
            [self.saved addItemWithTitle:[NSString stringWithUTF8StdString:i->host]];
        
        [self.saved.menu addItem:NSMenuItem.separatorItem];
        [self.saved addItemWithTitle:NSLocalizedString(@"Clear Recent Servers...", "Menu item titile for recents clearing action")];
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
    self.keypath = [NSString stringWithUTF8StdString:conn->keypath];
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
    alert.messageText = NSLocalizedString(@"Are you sure you want to clear the list of recent servers?", "Asking user if he want to clear recent connections");
    alert.informativeText = NSLocalizedString(@"You can't undo this action.", "Informating user that action can't be reverted");
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    if(alert.runModal == NSAlertFirstButtonReturn) {
        SavedNetworkConnectionsManager::Instance().EraseAllSFTPConnections();
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

- (IBAction)OnChooseKey:(id)sender
{
    auto initial_dir = access(g_SSHdir.c_str(), X_OK) == 0 ? g_SSHdir : CommonPaths::Get(CommonPaths::Home);
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

@end
