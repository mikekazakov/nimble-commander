//
//  NetworkShareSheetController.m
//  NimbleCommander
//
//  Created by Michael G. Kazakov on 3/24/17.
//  Copyright © 2017 Michael G. Kazakov. All rights reserved.
//

#import "NetworkShareSheetController.h"

@interface NetworkShareSheetController ()

@property (strong) NSString *title;
@property (strong) NSString *server;
@property (strong) NSString *share;
@property (strong) NSString *username;
@property (strong) NSString *password;
@property (strong) NSString *mountpath;
@property (strong) IBOutlet NSPopUpButton *protocol;
@end

@implementation NetworkShareSheetController
{
    optional<NetworkConnectionsManager::Connection> m_Original;
    NetworkConnectionsManager::LANShare m_Connection;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}


- (IBAction)onClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)onConnect:(id)sender
{
    if( m_Original)
        m_Connection.uuid = m_Original->Uuid();
    else
        m_Connection.uuid = NetworkConnectionsManager::Instance().MakeUUID();
    
    auto extract_string = [](NSString *s){ return s.UTF8String ? s.UTF8String : ""; };
    
    m_Connection.title = extract_string(self.title);
    m_Connection.share = extract_string(self.share);
    m_Connection.host = extract_string(self.server);
    m_Connection.user = extract_string(self.username);
    m_Connection.mountpoint = extract_string(self.mountpath);
    m_Connection.proto = NetworkConnectionsManager::LANShare::Protocol(self.protocol.selectedTag);
    
    
    [self endSheet:NSModalResponseOK];
}

- (NetworkConnectionsManager::Connection) connection
{
    return NetworkConnectionsManager::Connection( m_Connection );
}

- (NSString*) providedPassword
{
    return self.password ? self.password : @"";
}

@end
