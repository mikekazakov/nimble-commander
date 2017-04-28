#include "ConnectToServer.h"
#include "FTPConnectionSheetController.h"
#include "SFTPConnectionSheetController.h"
#include "NetworkShareSheetController.h"
#include "DropboxAccountSheetController.h"
#include <Utility/SheetWithHotkeys.h>
#include <NimbleCommander/Core/Alert.h>

namespace {
class SheetsDispatcher : public NetworkConnectionsManager::ConnectionVisitor
{
public:
    SheetsDispatcher( NetworkConnectionsManager::Connection _connection ):
        m_Connection(_connection)
    {
    }

    SheetController<ConnectionSheetProtocol> *CreateSheet()
    {
        m_Connection.Accept(*this);
        if( m_Sheet  )
            m_Sheet.connection = m_Connection;
        return m_Sheet;
    }

private:
    virtual void Visit( const NetworkConnectionsManager::FTPConnection &_ftp )
    {
        m_Sheet = [[FTPConnectionSheetController alloc] init];
    }
    
    virtual void Visit( const NetworkConnectionsManager::SFTPConnection &_sftp )
    {
        m_Sheet = [[SFTPConnectionSheetController alloc] init];
    }

    virtual void Visit( const NetworkConnectionsManager::LANShare &_share )
    {
        m_Sheet = [[NetworkShareSheetController alloc] init];
    }

    virtual void Visit( const NetworkConnectionsManager::Dropbox &_share )
    {
        m_Sheet = [[DropboxAccountSheetController alloc] init];
    }

    NetworkConnectionsManager::Connection m_Connection;
    SheetController<ConnectionSheetProtocol> *m_Sheet;
};

}

static void PeformClickIfEnabled( NSSegmentedControl* _control, int _segment )
{
    if( [_control isEnabledForSegment:_segment] ) {
        _control.selectedSegment = _segment;
        [_control performClick:nil];
    }
}

@interface ConnectToServer ()
@property (strong) IBOutlet NSTableView *connectionsTable;
@property (strong) IBOutlet NSSegmentedControl *controlButtons;
@property (strong) IBOutlet NSMenu *addNewConnectionMenu;

@end

@implementation ConnectToServer
{
    NetworkConnectionsManager                       *m_Manager;
    vector<NetworkConnectionsManager::Connection>   m_Connections;
    optional<NetworkConnectionsManager::Connection> m_OutputConnection;
    bool                                            m_Shown;
}

@synthesize connection = m_OutputConnection;

- (instancetype) initWithNetworkConnectionsManager:(NetworkConnectionsManager&)_manager
{
    self = [super init];
    if( self ) {
        m_Shown = false;
        m_Manager = &_manager;
    }
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
 
    auto sheet = objc_cast<SheetWithHotkeys>(self.window);
    sheet.onCtrlA = ^{ PeformClickIfEnabled(self.controlButtons, 0); };
    sheet.onCtrlX = ^{ PeformClickIfEnabled(self.controlButtons, 1); };
    sheet.onCtrlE = ^{ PeformClickIfEnabled(self.controlButtons, 2); };
    [self.controlButtons setMenu:self.addNewConnectionMenu forSegment:0];

    
    m_Connections = m_Manager->AllConnectionsByMRU();
}

- (void) reloadConnections
{
   m_Connections = m_Manager->AllConnectionsByMRU();
   [self.connectionsTable reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return m_Connections.size();
}

- (NSView *) makeTitleTableViewForConnection:(const NetworkConnectionsManager::Connection &)_c
{
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    if( auto l = [NSString stringWithUTF8StdString:_c.Title()] )
        tf.stringValue = l;
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    tf.usesSingleLineMode = true;
    tf.lineBreakMode = NSLineBreakByTruncatingTail;
    return tf;
}

- (NSView *) makePathTableViewForConnection:(const NetworkConnectionsManager::Connection &)_c
{
    NSTextField *tf = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 0, 0)];
    if( auto l = [NSString stringWithUTF8StdString:m_Manager->MakeConnectionPath(_c) ] )
        tf.stringValue = l;
    tf.bordered = false;
    tf.editable = false;
    tf.drawsBackground = false;
    tf.usesSingleLineMode = true;
    tf.lineBreakMode = NSLineBreakByTruncatingTail;
    return tf;
    return tf;
}

- (nullable NSView *)tableView:(NSTableView *)tableView
            viewForTableColumn:(nullable NSTableColumn *)tableColumn
                           row:(NSInteger)row
{
    if( row >= m_Connections.size() )
        return nil;

    const auto c = m_Connections[row];
    const auto identifier = tableColumn.identifier;

    if( [identifier isEqualToString:@"Title"] )
        return [self makeTitleTableViewForConnection:c];
    if( [identifier isEqualToString:@"Connection Path"] )
        return [self makePathTableViewForConnection:c];

    return nil;
}

- (IBAction)onClose:(id)sender
{
    [self endSheet:NSModalResponseCancel];
}

- (IBAction)onConnect:(id)sender
{
    const auto row = self.connectionsTable.selectedRow;
    if( row >= 0 )
        m_OutputConnection = m_Connections.at(row);

    [self endSheet:NSModalResponseOK];
}

- (IBAction)onEdit:(id)sender
{
    const auto row = self.connectionsTable.selectedRow;
    if( row < 0 )
        return;
    auto connection = m_Connections.at(row);
    
    SheetsDispatcher dispatcher{connection};
    auto sheet = dispatcher.CreateSheet();
    if( !sheet )
        return;

    string password;
    if( m_Manager->GetPassword(connection, password) )
        sheet.password = password;
    
    [sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode == NSModalResponseOK ) {
            const auto new_connection = sheet.connection;
            const auto new_password = sheet.password;
            if( new_connection != connection ) {
                m_Manager->InsertConnection(new_connection);
                [self reloadConnections];
            }
            if( new_password != password || new_connection != connection )
                m_Manager->SetPassword(new_connection, new_password);
        }
    }];
}

- (void)insertCreatedConnection:(NetworkConnectionsManager::Connection)_connection
                   withPassword:(const string&)_password
{
    m_Manager->InsertConnection(_connection);
    m_Manager->SetPassword(_connection, _password);
    
    [self reloadConnections];
}

- (void) runNewConnectionSheet:(SheetController<ConnectionSheetProtocol>*)_sheet
{
    [_sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode == NSModalResponseOK )
            [self insertCreatedConnection:_sheet.connection withPassword:_sheet.password];
    }];
}

- (IBAction)onAddFTPServer:(id)sender
{
    [self runNewConnectionSheet:[[FTPConnectionSheetController alloc] init]];
}

- (IBAction)onAddSFTPServer:(id)sender
{
    [self runNewConnectionSheet:[[SFTPConnectionSheetController alloc] init]];
}

- (IBAction)onAddNetworkShare:(id)sender
{
    [self runNewConnectionSheet:[[NetworkShareSheetController alloc] init]];
}

- (IBAction)onAddDropboxAccount:(id)sender
{
    [self runNewConnectionSheet:[[DropboxAccountSheetController alloc] init]];
}

- (IBAction)onControlButtonClicked:(id)sender
{
    const auto segment = self.controlButtons.selectedSegment;
    if( segment == 0 )
        [self showNewConnectionMenu:sender];
    else if( segment == 1 )
        [self onRemoveConnection:sender];
    else if( segment == 2 )
        [self onEdit:sender];
}

- (void) showNewConnectionMenu:(id)sender
{
    const auto origin = NSMakePoint(2, self.controlButtons.bounds.size.height + 3);
    [self.addNewConnectionMenu popUpMenuPositioningItem:nil
                                             atLocation:origin
                                                 inView:self.controlButtons];
}

- (void)onRemoveConnection:(id)sender
{
    const auto row = self.connectionsTable.selectedRow;
    if( row < 0 )
        return;
    auto connection = m_Connections.at(row);

    Alert *alert = [[Alert alloc] init];
    alert.messageText = NSLocalizedString(@"Are you sure you want to delete this connection?",
        "Asking user if he really wants to delete information about a stored connection");
    alert.informativeText = NSLocalizedString(@"You can’t undo this action.", "");
    [alert addButtonWithTitle:NSLocalizedString(@"Yes", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"No", "")];
    if( [alert runModal] == NSAlertFirstButtonReturn ) {
        m_Manager->RemoveConnection(connection);
        [self reloadConnections];
    }
}

@end
