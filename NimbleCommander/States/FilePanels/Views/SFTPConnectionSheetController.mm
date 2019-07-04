// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/CommonPaths.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <Utility/CocoaAppearanceManager.h>
#include <VFS/NetSFTP.h>
#include "SFTPConnectionSheetController.h"
#include <Utility/StringExtras.h>

static const auto g_SSHdir = CommonPaths::Home() + ".ssh/";

@interface SFTPConnectionSheetController()
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *server;
@property (nonatomic) NSString *username;
@property (nonatomic) NSString *passwordEntered;
@property (nonatomic) NSString *port;
@property (nonatomic) NSString *keypath;
@property (nonatomic) IBOutlet NSButton *connectButton;
@property (nonatomic) bool isValid;
@property (nonatomic) bool invalidPassword;
@property (nonatomic) bool invalidKeypath;

@end

static bool ValidateFileExistence( const std::string &_filepath )
{
    return access(_filepath.c_str(), R_OK) == 0;
}

@implementation SFTPConnectionSheetController
{
    std::optional<NetworkConnectionsManager::Connection> m_Original;
    NetworkConnectionsManager::SFTP m_Connection;
}

- (id) init
{
    self = [super init];
    if(self) {
        
        std::string rsa_path = g_SSHdir + "id_rsa";
        std::string dsa_path = g_SSHdir + "id_dsa";
        
        if( ValidateFileExistence(rsa_path) )
            self.keypath = [NSString stringWithUTF8StdString:rsa_path];
        else if( ValidateFileExistence(dsa_path) )
            self.keypath = [NSString stringWithUTF8StdString:dsa_path];
        
        self.isValid = false;
        self.invalidPassword = false;
        self.invalidKeypath = false;
    }
    return self;
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    nc::utility::CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);

    if( self.setupMode )
        self.connectButton.title = self.connectButton.alternateTitle;

    GA().PostScreenView("SFTP Connection");
    
    
    if( m_Original ) {
        auto &c = m_Original->Get<NetworkConnectionsManager::SFTP>();
        self.title = [NSString stringWithUTF8StdString:c.title];
        self.server = [NSString stringWithUTF8StdString:c.host];
        self.username = [NSString stringWithUTF8StdString:c.user];
        self.keypath = [NSString stringWithUTF8StdString:c.keypath];
        self.port = [NSString stringWithFormat:@"%li", c.port];
    }
    
    [self validate];    
}

- (IBAction)OnConnect:(id)[[maybe_unused]]_sender
{
    if( m_Original)
        m_Connection.uuid = m_Original->Uuid();
    else
        m_Connection.uuid =  NetworkConnectionsManager::MakeUUID();
    
    m_Connection.title = self.title.UTF8String ? self.title.UTF8String : "";
    m_Connection.host = self.server.UTF8String ? self.server.UTF8String : "";
    m_Connection.user = self.username ? self.username.UTF8String : "";
    m_Connection.keypath = self.keypath ? self.keypath.UTF8String : "";
    m_Connection.port = 22;
    if(self.port.intValue != 0)
        m_Connection.port = self.port.intValue;
    
    [self endSheet:NSModalResponseOK];
}

- (IBAction)OnClose:(id)[[maybe_unused]]_sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnChooseKey:(id)[[maybe_unused]]_sender
{
    auto initial_dir = access(g_SSHdir.c_str(), X_OK) == 0 ? g_SSHdir : CommonPaths::Home();
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = false;
    panel.canChooseFiles = true;
    panel.canChooseDirectories = false;
    panel.directoryURL = [[NSURL alloc] initFileURLWithPath:[NSString stringWithUTF8StdString:initial_dir]
                                                isDirectory:true];
    [panel beginSheetModalForWindow:self.window
                  completionHandler:^(NSInteger result){
                      if(result == NSFileHandlingPanelOKButton) {
                          self.keypath = panel.URL.path;
                          [self validate];
                      }
                  }];
}

- (void)setConnection:(NetworkConnectionsManager::Connection)connection
{
    m_Original = connection;
}

- (NetworkConnectionsManager::Connection)connection
{
    return NetworkConnectionsManager::Connection( m_Connection );
}

- (void) setPassword:(std::string)password
{
    self.passwordEntered = [NSString stringWithUTF8StdString:password];
}

- (std::string)password
{
    return self.passwordEntered ? self.passwordEntered.UTF8String : "";
}

- (bool)validateServer
{
    return self.server && self.server.length > 0;
}

- (bool)validateUsername
{
    return self.username && self.username.length > 0;
}

- (bool)validatePort
{
    return !self.port ||
            (self.port.length == 0) ||
            (self.port.intValue > 0 && self.port.intValue < 65'536);
}

- (bool)validateKeypath
{
    const auto entered_keypath = self.keypath && self.keypath.length != 0;
    if( !entered_keypath ) {
        self.invalidPassword = false;
        self.invalidKeypath = false;
        return true;
    }

    if( !ValidateFileExistence(self.keypath.fileSystemRepresentationSafe) ) {
        self.invalidKeypath = true;
        self.invalidPassword = false;
        return false;
    }
    
    self.invalidKeypath = false;

    nc::vfs::sftp::KeyValidator validator{self.keypath.fileSystemRepresentation,
                                          self.passwordEntered.UTF8String ?
                                          self.passwordEntered.UTF8String :
                                          ""};
    if( validator.Validate() ) {
        self.invalidPassword = false;
        return true;
    }
    else {
        self.invalidPassword = true;
        return false;
    }
}

- (bool)validatePassword
{
    const auto entered_keypath = self.keypath && self.keypath.length != 0;
    const auto entered_password = self.passwordEntered && self.passwordEntered.length != 0;
    return entered_keypath || entered_password;
}

- (void)validate
{
    const auto valid_server = [self validateServer];
    const auto valid_username = [self validateUsername];
    const auto valid_port = [self validatePort];
    const auto valid_password = [self validatePassword];
    const auto valid_keypath = [self validateKeypath];
    self.isValid = valid_server && valid_username && valid_port && valid_password && valid_keypath;
}

- (void)controlTextDidChange:(NSNotification *)[[maybe_unused]]_obj
{
    [self validate];
}

@end
