#include <NimbleCommander/Core/Alert.h>
#include "NetworkShareSheetController.h"

@interface NetworkShareSheetController ()

@property (strong) NSString *title;
@property (strong) NSString *server;
@property (strong) NSString *share;
@property (strong) NSString *username;
@property (strong) NSString *passwordEntered;
@property (strong) NSString *mountpath;
@property (strong) IBOutlet NSPopUpButton *protocol;
@property (strong) IBOutlet NSPopUpButton *saved;

@property bool valid;
@property bool nfsSelected;
@end

@implementation NetworkShareSheetController
{
//    vector<NetworkConnectionsManager::Connection> m_Connections;
    optional<NetworkConnectionsManager::Connection> m_Original;
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
    
    if( m_Original )
        [self fillInfoFromConnection:*m_Original];
    
    [self validate];
    
//    m_Connections = Manager().LANShareConnectionsByMRU();
    
//    if(!m_Connections.empty()) {
//        self.saved.autoenablesItems = false;
//        
//        NSMenuItem *pref = [[NSMenuItem alloc] init];
//        pref.title = NSLocalizedString(@"Recent Servers", "Menu item title, disabled - only as separator");
//        pref.enabled = false;
//        [self.saved.menu addItem:pref];
//        
//        for(auto &i: m_Connections) {
//            NSMenuItem *it = [NSMenuItem new];
//            auto title = Manager().TitleForConnection(i);
//            it.title = [NSString stringWithUTF8StdString:title];
//            [self.saved.menu addItem:it];
//        }
//        
//        [self.saved.menu addItem:NSMenuItem.separatorItem];
//        [self.saved addItemWithTitle:NSLocalizedString(@"Clear Recent Servers...", "Menu item titile for recents clearing action")];
//    }
    
}

- (IBAction)OnSaved:(id)sender
{
//    long ind = self.saved.indexOfSelectedItem;
//    if(ind == self.saved.numberOfItems - 1) {
//        [self ClearRecentServers];
//        return;
//    }
//    
//    ind = ind - 2;
//    if(ind < 0 || ind >= m_Connections.size())
//        return;
//    
//    m_Original = m_Connections[ind];
//    [self fillInfoFromConnection:*m_Original];
//    [self validate];
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
    
//    string password;
//    if( Manager().GetPassword(_conn, password) )
//        self.passwordEntered = [NSString stringWithUTF8StdString:password];
//    else
//        self.passwordEntered = @"";
}

- (void) ClearRecentServers
{
//    Alert *alert = [[Alert alloc] init];
//    alert.messageText = NSLocalizedString(@"Are you sure you want to clear the list of recent servers?", "Asking user if he want to clear recent connections");
//    alert.informativeText = NSLocalizedString(@"You can’t undo this action.", "Informating user that action can't be reverted");
//    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
//    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
//    if(alert.runModal == NSAlertFirstButtonReturn) {
//        for( auto &i: m_Connections )
//            Manager().RemoveConnection(i);
//        m_Connections.clear();
//        [self.saved selectItemAtIndex:0];
//        while( self.saved.numberOfItems > 1 )
//            [self.saved removeItemAtIndex:self.saved.numberOfItems - 1];
//    }
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
    [self fillInfoFromConnection:*m_Original];
}

//@property (readonly) NetworkConnectionsManager::Connection connection;

- (NSString*) providedPassword
{
    return self.passwordEntered ? self.passwordEntered : @"";
}

//@property (nonatomic) string password;

- (string)password
{
    return self.passwordEntered ? self.passwordEntered.UTF8String : "";
}

- (void)setPassword:(string)password
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
