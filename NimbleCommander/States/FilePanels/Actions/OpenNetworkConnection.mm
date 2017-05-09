#include "OpenNetworkConnection.h"
#include "../PanelController.h"
#include "../Views/FTPConnectionSheetController.h"
#include "../Views/SFTPConnectionSheetController.h"
#include "../Views/NetworkShareSheetController.h"
#include "../Views/ConnectToServer.h"
#include "../Views/DropboxAccountSheetController.h"
#include <VFS/Native.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/NetDropbox.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/AnyHolder.h>

namespace nc::panel::actions {

static bool GoToFTP(PanelController *_target,
                    const NetworkConnectionsManager::Connection &_connection,
                    const string& _passwd)
{
    dispatch_assert_background_queue();    
    auto &info = _connection.Get<NetworkConnectionsManager::FTP>();
    try {
        auto host = make_shared<VFSNetFTPHost>(info.host,
                                               info.user,
                                               _passwd,
                                               info.path,
                                               info.port
                                               );
        dispatch_to_main_queue([=]{
//            m_DirectoryLoadingQ.Wait(); // just to be sure that GoToDir will not exit immed due to non-empty loading que

            [_target GoToDir:info.path vfs:host select_entry:"" async:true];
        });
        
        // save successful connection usage to history
        _target.networkConnectionsManager.ReportUsage(_connection);
        
        return true;
    } catch (VFSErrorException &e) {
        dispatch_to_main_queue([=]{
            Alert *alert = [[Alert alloc] init];
            alert.messageText = NSLocalizedString(@"FTP connection error:", "Showing error when connecting to FTP server");
            alert.informativeText = VFSError::ToNSError(e.code()).localizedDescription;
            [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
            [alert runModal];
        });
    }
    return false;
}

static bool GoToSFTP(PanelController *_target,
                     const NetworkConnectionsManager::Connection &_connection,
                     const string& _passwd)
{
    dispatch_assert_background_queue();
    auto &info = _connection.Get<NetworkConnectionsManager::SFTP>();
    try {
        auto host = make_shared<VFSNetSFTPHost>(info.host,
                                                info.user,
                                                _passwd,
                                                info.keypath,
                                                info.port
                                                );
        dispatch_to_main_queue([=]{
//            m_DirectoryLoadingQ.Wait(); // just to be sure that GoToDir will not exit immed due to non-empty loading que
            [_target GoToDir:host->HomeDir() vfs:host select_entry:"" async:true];
        });
        
        // save successful connection to history
        _target.networkConnectionsManager.ReportUsage(_connection);

        return true;
    } catch (const VFSErrorException &e) {
        dispatch_to_main_queue([=]{
            Alert *alert = [[Alert alloc] init];
            alert.messageText = NSLocalizedString(@"SFTP connection error:", "Showing error when connecting to SFTP server");
            alert.informativeText = VFSError::ToNSError(e.code()).localizedDescription;
            [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
            [alert runModal];
        });
    }
    return false;
}

static void GoToDropboxStorage(PanelController *_target,
                               const NetworkConnectionsManager::Connection &_connection,
                               const string&_passwd)
{
    dispatch_assert_background_queue();
    auto &info = _connection.Get<NetworkConnectionsManager::Dropbox>();
    try {
        auto host = make_shared<VFSNetDropboxHost>(info.account, _passwd);
        dispatch_to_main_queue([=]{
//            m_DirectoryLoadingQ.Wait(); // just to be sure that GoToDir will not exit immed due to non-empty loading que
            [_target GoToDir:"/" vfs:host select_entry:"" async:true];
        });
        
        // save successful connection to history
        _target.networkConnectionsManager.ReportUsage(_connection);
    } catch (const VFSErrorException &e) {
        dispatch_to_main_queue([=]{
            Alert *alert = [[Alert alloc] init];
            alert.messageText = NSLocalizedString(@"Dropbox connection error:", "Showing error when connecting to Dropbox service");
            alert.informativeText = VFSError::ToNSError(e.code()).localizedDescription;
            [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
            [alert runModal];
        });
    }
}

static void GoToLANShare(PanelController *_target,
                         const NetworkConnectionsManager::Connection &_connection,
                         const string& _passwd,
                         bool _save_password_on_success)
{
    auto activity = make_shared<nc::panel::ActivityTicket>();
    __weak PanelController *weak_panel = _target;
    auto cb = [weak_panel, activity, _connection, _passwd, _save_password_on_success]
        (const string &_path, const string &_err) {
        if( PanelController *panel = weak_panel ) {
            if( !_path.empty() ) {
                [panel GoToDir:_path
                           vfs:VFSNativeHost::SharedHost()
                  select_entry:""
                         async:true];
                
                // save successful connection to history
                panel.networkConnectionsManager.ReportUsage(_connection);
                if( _save_password_on_success )
                    panel.networkConnectionsManager.SetPassword(_connection, _passwd);
            }
            else {
                dispatch_to_main_queue([=]{
                    Alert *alert = [[Alert alloc] init];
                    alert.messageText = NSLocalizedString(@"Unable to connect to a network share",
                                                          "Informing a user that NC can't connect to network share");
                    alert.informativeText = [NSString stringWithUTF8StdString:_err];
                    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
                    [alert runModal];
                });
            }
        }
    };
    
    if( _target.networkConnectionsManager.MountShareAsync(_connection, _passwd, cb) )
        *activity = [_target registerExtActivity];
}

void OpenNewFTPConnection::Perform(PanelController *_target, id _sender) const
{
    const auto sheet = [[FTPConnectionSheetController alloc] init];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto connection = sheet.connection;
        string password = sheet.password;
        
        _target.networkConnectionsManager.InsertConnection(connection);
        _target.networkConnectionsManager.SetPassword(connection, password);
        
        dispatch_to_background([=]{
            auto activity = [_target registerExtActivity];
            GoToFTP(_target, connection, password);
        });
    }];
}

void OpenNewSFTPConnection::Perform(PanelController *_target, id _sender) const
{
    const auto sheet = [[SFTPConnectionSheetController alloc] init];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode != NSModalResponseOK)
            return;
            
        auto connection = sheet.connection;
        string password = sheet.password;
        
        _target.networkConnectionsManager.InsertConnection(connection);
        _target.networkConnectionsManager.SetPassword(connection, password);
        dispatch_to_background([=]{
            auto activity = [_target registerExtActivity];
            GoToSFTP(_target, connection, password);
        });
    }];
}

void OpenNewDropboxStorage::Perform(PanelController *_target, id _sender) const
{
    const auto sheet = [[DropboxAccountSheetController alloc] init];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode != NSModalResponseOK)
            return;
            
        auto connection = sheet.connection;
        string password = sheet.password;
        
        _target.networkConnectionsManager.InsertConnection(connection);
        _target.networkConnectionsManager.SetPassword(connection, password);
        dispatch_to_background([=]{
            auto activity = [_target registerExtActivity];
            GoToDropboxStorage(_target, connection, password);
        });
    }];
}

void OpenNewLANShare::Perform(PanelController *_target, id _sender) const
{
    const auto sheet = [[NetworkShareSheetController alloc] init];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode != NSModalResponseOK)
            return;
        
        auto connection = sheet.connection;
        auto password = sheet.password;
        _target.networkConnectionsManager.InsertConnection(connection);
        _target.networkConnectionsManager.SetPassword(connection, password);
        
        GoToLANShare(_target, connection, password, false);
    }];
}

static void GoToConnection(PanelController *_target,
                           const NetworkConnectionsManager::Connection &connection)
{
    string passwd;
    bool should_save_passwd = false;
    if( !_target.networkConnectionsManager.GetPassword(connection, passwd) ) {
        if( !_target.networkConnectionsManager.AskForPassword(connection, passwd) )
            return;
        should_save_passwd = true;
    }
    
    
    if( connection.IsType<NetworkConnectionsManager::FTP>() )
        dispatch_to_background([=]{
            auto activity = [_target registerExtActivity];
            bool success = GoToFTP(_target, connection, passwd);
            if( success && should_save_passwd )
                 _target.networkConnectionsManager.SetPassword(connection, passwd);
        });
    else if( connection.IsType<NetworkConnectionsManager::SFTP>() )
        dispatch_to_background([=]{
            auto activity = [_target registerExtActivity];
            bool success = GoToSFTP(_target, connection, passwd);
            if( success && should_save_passwd )
                 _target.networkConnectionsManager.SetPassword(connection, passwd);
            
        });
    else if( connection.IsType<NetworkConnectionsManager::LANShare>() )
        GoToLANShare(_target, connection, passwd, should_save_passwd);
    else if( connection.IsType<NetworkConnectionsManager::Dropbox>() )
        dispatch_to_background([=]{
            auto activity = [_target registerExtActivity];
            GoToDropboxStorage(_target, connection, passwd);
        });
}

void OpenNetworkConnections::Perform( PanelController *_target, id _sender ) const
{
    const auto sheet = [[ConnectToServer alloc] initWithNetworkConnectionsManager:
              _target.networkConnectionsManager];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        if( !sheet.connection )
            return;
        GoToConnection(_target, *sheet.connection);
    }];
}

void OpenExistingNetworkConnection::Perform(PanelController *_target, id _sender) const
{
    if( auto menuitem = objc_cast<NSMenuItem>(_sender) )
        if( auto holder = objc_cast<AnyHolder>(menuitem.representedObject) )
            if( auto conn = any_cast<NetworkConnectionsManager::Connection>(&holder.any) )
                GoToConnection(_target, *conn);
}


}
