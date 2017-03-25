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

- (instancetype) init
{
    if(self = [super init]) {
    }
    return self;
}

- (instancetype) initWithConnection:(NetworkConnectionsManager::Connection)_connection
{
    if(self = [super init]) {
        m_Original = _connection;
    }
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    if( m_Original )
        [self fillInfoFromConnection:*m_Original];
}

- (void)fillInfoFromConnection:(NetworkConnectionsManager::Connection)_conn
{
    auto &c = _conn.Get<NetworkConnectionsManager::LANShare>();
    
    self.title = [NSString stringWithUTF8StdString:c.title];
    self.server = [NSString stringWithUTF8StdString:c.host];
    self.username = [NSString stringWithUTF8StdString:c.user];
    self.share = [NSString stringWithUTF8StdString:c.share];
    self.mountpath = [NSString stringWithUTF8StdString:c.mountpoint];
    [self.protocol selectItemWithTag:(int)c.proto];
    
    string password;
    if( NetworkConnectionsManager::Instance().GetPassword(_conn, password) )
        self.password = [NSString stringWithUTF8StdString:password];
    else
        self.password = @"";
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

- (IBAction)onChooseMountPath:(id)sender
{
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.resolvesAliases = false;
    panel.canChooseDirectories = true;
    panel.canChooseFiles = false;
    panel.allowsMultipleSelection = false;
    panel.showsHiddenFiles = true;
    panel.treatsFilePackagesAsDirectories = true;

    if( [panel runModal] == NSFileHandlingPanelOKButton ) {
        if( panel.URL )
            self.mountpath = panel.URL.path;
    }
}

// TODO: validation

@end
