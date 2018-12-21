// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "NetworkShareSheetController.h"
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include <Utility/StringExtras.h>

@interface NetworkShareSheetController ()

@property (nonatomic) NSString *title;
@property (nonatomic) NSString *server;
@property (nonatomic) NSString *share;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *passwordEntered;
@property (nonatomic) NSString *mountpath;
@property (nonatomic) IBOutlet NSPopUpButton *protocol;
@property (nonatomic) IBOutlet NSButton *connectButton;

@property (nonatomic) bool valid;
@property (nonatomic) bool nfsSelected;
@end

@implementation NetworkShareSheetController
{
    std::optional<NetworkConnectionsManager::Connection> m_Original;
    NetworkConnectionsManager::LANShare m_Connection;    
}

- (instancetype) init
{
    if(self = [super init]) {
        self.valid = true;
        self.nfsSelected = false;
    }
    return self;
}

- (instancetype) initWithConnection:(NetworkConnectionsManager::Connection)_connection
{
    if(self = [self init]) {
        m_Original = _connection;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);
    
    GA().PostScreenView("LANShare Connection");
    
    if( self.setupMode )
        self.connectButton.title = self.connectButton.alternateTitle;
    
    if( m_Original ) {
        auto &c = m_Original->Get<NetworkConnectionsManager::LANShare>();
        self.title = [NSString stringWithUTF8StdString:c.title];
        self.server = [NSString stringWithUTF8StdString:c.host];
        self.username = [NSString stringWithUTF8StdString:c.user];
        self.share = [NSString stringWithUTF8StdString:c.share];
        self.mountpath = [NSString stringWithUTF8StdString:c.mountpoint];
        [self.protocol selectItemWithTag:(int)c.proto];
    }
    
    [self validate];
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
        m_Connection.uuid = NetworkConnectionsManager::MakeUUID();
    
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

- (void)setConnection:(NetworkConnectionsManager::Connection)connection
{
    m_Original = connection;
}

- (NSString*) providedPassword
{
    return self.passwordEntered ? self.passwordEntered : @"";
}

- (std::string)password
{
    return self.passwordEntered ? self.passwordEntered.UTF8String : "";
}

- (void)setPassword:(std::string)password
{
    self.passwordEntered = [NSString stringWithUTF8StdString:password];
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

- (IBAction)onServerChanged:(id)sender
{
    [self validate];
}

- (IBAction)onShareChanged:(id)sender
{
    [self validate];
}

- (IBAction)onMountPathChanged:(id)sender
{
    [self validate];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    [self validate];
}

- (IBAction)onProtocolChanged:(id)sender
{
    [self validate];
}

- (void) validate
{
    self.valid = [self isValid];
    self.nfsSelected = self.protocol.selectedTag ==
        (int)NetworkConnectionsManager::LANShare::Protocol::NFS;
}

- (bool) isValid
{
    if( self.server == nil ||
        self.server.length == 0 ||
       [self.server containsString:@"/"] ||
       [self.server containsString:@":"] )
        return false;
    
    if( self.share == nil || self.share.length == 0 )
        return false;

    if( self.mountpath != nil && self.mountpath.length != 0 )
        if( [self.mountpath characterAtIndex:0] != '/' )
            return false;

    return true;
}

@end
