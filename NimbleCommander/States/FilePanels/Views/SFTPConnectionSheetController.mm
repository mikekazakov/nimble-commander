#include <Habanero/CommonPaths.h>
#include <NimbleCommander/Core/GoogleAnalytics.h>
#include <NimbleCommander/Core/Theming/CocoaAppearanceManager.h>
#include "SFTPConnectionSheetController.h"

static const auto g_SSHdir = CommonPaths::Home() + ".ssh/";

@interface SFTPConnectionSheetController()
@property (strong) NSString *title;
@property (strong) NSString *server;
@property (strong) NSString *username;
@property (strong) NSString *passwordEntered;
@property (strong) NSString *port;
@property (strong) NSString *keypath;
@property (strong) IBOutlet NSButton *connectButton;

- (IBAction)OnConnect:(id)sender;
- (IBAction)OnClose:(id)sender;
- (IBAction)OnChooseKey:(id)sender;
- (void)fillInfoFromStoredConnection:(NetworkConnectionsManager::Connection)_conn;
@property (readonly, nonatomic) NetworkConnectionsManager::Connection result;
@end


@implementation SFTPConnectionSheetController
{
    optional<NetworkConnectionsManager::Connection> m_Original;
    NetworkConnectionsManager::SFTP m_Connection;
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
    [super windowDidLoad];
    CocoaAppearanceManager::Instance().ManageWindowApperance(self.window);

    if( self.setupMode )
        self.connectButton.title = self.connectButton.alternateTitle;

    GA().PostScreenView("SFTP Connection");
}

- (void)fillInfoFromStoredConnection:(NetworkConnectionsManager::Connection)_conn
{
    [self window];

    m_Original = _conn;
    auto &c = m_Original->Get<NetworkConnectionsManager::SFTP>();
    
    self.title = [NSString stringWithUTF8StdString:c.title];
    self.server = [NSString stringWithUTF8StdString:c.host];
    self.username = [NSString stringWithUTF8StdString:c.user];
    self.keypath = [NSString stringWithUTF8StdString:c.keypath];
    self.port = [NSString stringWithFormat:@"%li", c.port];
}

- (IBAction)OnConnect:(id)sender
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

- (IBAction)OnClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)OnChooseKey:(id)sender
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
                      if(result == NSFileHandlingPanelOKButton)
                          self.keypath = panel.URL.path;
                  }];
}

- (NetworkConnectionsManager::Connection) result
{
    return NetworkConnectionsManager::Connection( m_Connection );
}

- (void)setConnection:(NetworkConnectionsManager::Connection)connection
{
    [self fillInfoFromStoredConnection:connection];
}

- (NetworkConnectionsManager::Connection)connection
{
    return NetworkConnectionsManager::Connection( m_Connection );
}

- (void) setPassword:(string)password
{
    self.passwordEntered = [NSString stringWithUTF8StdString:password];
}

- (string)password
{
    return self.passwordEntered ? self.passwordEntered.UTF8String : "";
}

@end
