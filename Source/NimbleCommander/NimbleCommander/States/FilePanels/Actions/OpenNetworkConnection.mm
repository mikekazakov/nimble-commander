// Copyright (C) 2017-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "OpenNetworkConnection.h"
#include "../PanelController.h"
#include "../Views/FTPConnectionSheetController.h"
#include "../Views/SFTPConnectionSheetController.h"
#include "../Views/NetworkShareSheetController.h"
#include "../Views/ConnectToServer.h"
#include "../Views/DropboxAccountSheetController.h"
#include "../Views/WebDAVConnectionSheetController.h"
#include <VFS/Native.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <VFS/NetDropbox.h>
#include <VFS/NetWebDAV.h>
#include <NimbleCommander/Bootstrap/NativeVFSHostInstance.h>
#include <NimbleCommander/Bootstrap/NCE.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include <Base/dispatch_cpp.h>
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include <CUI/CommandPopover.h>

namespace nc::panel::actions {

OpenConnectionBase::OpenConnectionBase(NetworkConnectionsManager &_net_mgr) : m_NetMgr(_net_mgr)
{
}

static bool GoToFTP(PanelController *_target,
                    const NetworkConnectionsManager::Connection &_connection,
                    const std::string &_passwd,
                    NetworkConnectionsManager &_net_mgr)
{
    dispatch_assert_background_queue();
    auto &info = _connection.Get<NetworkConnectionsManager::FTP>();
    try {
        auto host = std::make_shared<vfs::FTPHost>(info.host, info.user, _passwd, info.path, info.port, info.active);
        dispatch_to_main_queue([=] {
            auto request = std::make_shared<DirectoryChangeRequest>();
            request->RequestedDirectory = info.path;
            request->VFS = host;
            request->PerformAsynchronous = true;
            request->InitiatedByUser = true;
            [_target GoToDirWithContext:request];
        });

        // save successful connection usage to history
        _net_mgr.ReportUsage(_connection);

        return true;
    } catch( const ErrorException &e ) {
        dispatch_to_main_queue([=] {
            Alert *const alert = [[Alert alloc] init];
            alert.messageText =
                NSLocalizedString(@"FTP connection error:", "Showing error when connecting to FTP server");
            alert.informativeText = [NSString stringWithUTF8StdString:e.error().LocalizedFailureReason()];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
            [alert runModal];
        });
    }
    return false;
}

static bool GoToSFTP(PanelController *_target,
                     const NetworkConnectionsManager::Connection &_connection,
                     const std::string &_passwd,
                     NetworkConnectionsManager &_net_mgr)
{
    dispatch_assert_background_queue();
    auto &info = _connection.Get<NetworkConnectionsManager::SFTP>();
    try {
        auto host = std::make_shared<vfs::SFTPHost>(info.host, info.user, _passwd, info.keypath, info.port);
        dispatch_to_main_queue([=] {
            auto request = std::make_shared<DirectoryChangeRequest>();
            request->RequestedDirectory = host->HomeDir();
            request->VFS = host;
            request->PerformAsynchronous = true;
            request->InitiatedByUser = true;
            [_target GoToDirWithContext:request];
        });

        // save successful connection to history
        _net_mgr.ReportUsage(_connection);

        return true;
    } catch( const ErrorException &e ) {
        dispatch_to_main_queue([=] {
            Alert *const alert = [[Alert alloc] init];
            alert.messageText =
                NSLocalizedString(@"SFTP connection error:", "Showing error when connecting to SFTP server");
            alert.informativeText = [NSString stringWithUTF8StdString:e.error().LocalizedFailureReason()];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
            [alert runModal];
        });
    }
    return false;
}

static bool GoToWebDAV(PanelController *_target,
                       const NetworkConnectionsManager::Connection &_connection,
                       const std::string &_passwd,
                       NetworkConnectionsManager &_net_mgr)
{
    dispatch_assert_background_queue();
    auto &info = _connection.Get<NetworkConnectionsManager::WebDAV>();
    try {
        auto host = std::make_shared<vfs::WebDAVHost>(info.host, info.user, _passwd, info.path, info.https, info.port);
        dispatch_to_main_queue([=] {
            auto request = std::make_shared<DirectoryChangeRequest>();
            request->RequestedDirectory = "/";
            request->VFS = host;
            request->PerformAsynchronous = true;
            request->InitiatedByUser = true;
            [_target GoToDirWithContext:request];
        });

        // save successful connection to history
        _net_mgr.ReportUsage(_connection);

        return true;
    } catch( const ErrorException &e ) {
        dispatch_to_main_queue([=] {
            Alert *const alert = [[Alert alloc] init];
            alert.messageText =
                NSLocalizedString(@"WebDAV connection error:", "Showing error when connecting to WebDAV server");
            alert.informativeText = [NSString stringWithUTF8StdString:e.error().LocalizedFailureReason()];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
            [alert runModal];
        });
    }
    return false;
}

static void GoToDropboxStorage(PanelController *_target,
                               const NetworkConnectionsManager::Connection &_connection,
                               const std::string &_passwd,
                               NetworkConnectionsManager &_net_mgr)
{
    dispatch_assert_background_queue();
    auto &info = _connection.Get<NetworkConnectionsManager::Dropbox>();
    try {
        vfs::DropboxHost::Params params;
        params.account = info.account;
        params.access_token = _passwd;
        params.client_id = NCE(nc::env::dropbox_client_id);
        params.client_secret = NCE(nc::env::dropbox_client_secret);
        auto host = std::make_shared<vfs::DropboxHost>(params);
        dispatch_to_main_queue([=] {
            auto request = std::make_shared<DirectoryChangeRequest>();
            request->RequestedDirectory = "/";
            request->VFS = host;
            request->PerformAsynchronous = true;
            request->InitiatedByUser = true;
            [_target GoToDirWithContext:request];
        });

        // save successful connection to history
        _net_mgr.ReportUsage(_connection);
    } catch( const ErrorException &e ) {
        dispatch_to_main_queue([=] {
            Alert *const alert = [[Alert alloc] init];
            alert.messageText =
                NSLocalizedString(@"Dropbox connection error:", "Showing error when connecting to Dropbox service");
            alert.informativeText = [NSString stringWithUTF8StdString:e.error().LocalizedFailureReason()];
            [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
            [alert runModal];
        });
    }
}

static void GoToLANShare(PanelController *_target,
                         const NetworkConnectionsManager::Connection &_connection,
                         const std::string &_passwd,
                         bool _save_password_on_success,
                         NetworkConnectionsManager &_net_mgr)
{
    auto activity = std::make_shared<nc::panel::ActivityTicket>();
    __weak PanelController *weak_panel = _target;
    auto cb = [weak_panel, activity, _connection, _passwd, _save_password_on_success, &_net_mgr](
                  const std::string &_path, const std::string &_err) {
        if( PanelController *const panel = weak_panel ) {
            if( !_path.empty() ) {
                auto request = std::make_shared<DirectoryChangeRequest>();
                request->RequestedDirectory = _path;
                request->VFS = nc::bootstrap::NativeVFSHostInstance().SharedPtr();
                request->PerformAsynchronous = true;
                request->InitiatedByUser = true;
                [panel GoToDirWithContext:request];

                // save successful connection to history
                _net_mgr.ReportUsage(_connection);
                if( _save_password_on_success )
                    _net_mgr.SetPassword(_connection, _passwd);
            }
            else {
                dispatch_to_main_queue([=] {
                    Alert *const alert = [[Alert alloc] init];
                    alert.messageText = NSLocalizedString(@"Unable to connect to a network share",
                                                          "Informing a user that NC can't connect to network share");
                    alert.informativeText = [NSString stringWithUTF8StdString:_err];
                    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
                    [alert runModal];
                });
            }
        }
    };

    if( _net_mgr.MountShareAsync(_connection, _passwd, cb) )
        *activity = [_target registerExtActivity];
}

OpenNewFTPConnection::OpenNewFTPConnection(NetworkConnectionsManager &_net_mgr) : OpenConnectionBase(_net_mgr)
{
}

void OpenNewFTPConnection::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto sheet = [[FTPConnectionSheetController alloc] init];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window
             completionHandler:^(NSModalResponse returnCode) {
               if( returnCode != NSModalResponseOK )
                   return;

               auto connection = sheet.connection;
               const std::string password = sheet.password;

               m_NetMgr.InsertConnection(connection);
               m_NetMgr.SetPassword(connection, password);

               dispatch_to_background([=, this] {
                   auto activity = [_target registerExtActivity];
                   GoToFTP(_target, connection, password, m_NetMgr);
               });
             }];
}

OpenNewSFTPConnection::OpenNewSFTPConnection(NetworkConnectionsManager &_net_mgr) : OpenConnectionBase(_net_mgr)
{
}

void OpenNewSFTPConnection::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto sheet = [[SFTPConnectionSheetController alloc] init];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window
             completionHandler:^(NSModalResponse returnCode) {
               if( returnCode != NSModalResponseOK )
                   return;

               auto connection = sheet.connection;
               const std::string password = sheet.password;

               m_NetMgr.InsertConnection(connection);
               m_NetMgr.SetPassword(connection, password);
               dispatch_to_background([=, this] {
                   auto activity = [_target registerExtActivity];
                   GoToSFTP(_target, connection, password, m_NetMgr);
               });
             }];
}

OpenNewDropboxStorage::OpenNewDropboxStorage(NetworkConnectionsManager &_net_mgr) : OpenConnectionBase(_net_mgr)
{
}

void OpenNewDropboxStorage::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto sheet = [[DropboxAccountSheetController alloc] init];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window
             completionHandler:^(NSModalResponse returnCode) {
               if( returnCode != NSModalResponseOK )
                   return;

               auto connection = sheet.connection;
               const std::string password = sheet.password;

               m_NetMgr.InsertConnection(connection);
               m_NetMgr.SetPassword(connection, password);
               dispatch_to_background([=, this] {
                   auto activity = [_target registerExtActivity];
                   GoToDropboxStorage(_target, connection, password, m_NetMgr);
               });
             }];
}

OpenNewLANShare::OpenNewLANShare(NetworkConnectionsManager &_net_mgr) : OpenConnectionBase(_net_mgr)
{
}

void OpenNewLANShare::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto sheet = [[NetworkShareSheetController alloc] init];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window
             completionHandler:^(NSModalResponse returnCode) {
               if( returnCode != NSModalResponseOK )
                   return;

               auto connection = sheet.connection;
               auto password = sheet.password;
               m_NetMgr.InsertConnection(connection);
               m_NetMgr.SetPassword(connection, password);

               GoToLANShare(_target, connection, password, false, m_NetMgr);
             }];
}

OpenNewWebDAVConnection::OpenNewWebDAVConnection(NetworkConnectionsManager &_net_mgr) : OpenConnectionBase(_net_mgr)
{
}

void OpenNewWebDAVConnection::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto sheet = [[WebDAVConnectionSheetController alloc] init];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window
             completionHandler:^(NSModalResponse returnCode) {
               if( returnCode != NSModalResponseOK )
                   return;

               auto connection = sheet.connection;
               const std::string password = sheet.password;

               m_NetMgr.InsertConnection(connection);
               m_NetMgr.SetPassword(connection, password);
               dispatch_to_background([=, this] {
                   auto activity = [_target registerExtActivity];
                   GoToWebDAV(_target, connection, password, m_NetMgr);
               });
             }];
}

static void GoToConnection(PanelController *_target,
                           const NetworkConnectionsManager::Connection &connection,
                           NetworkConnectionsManager &_net_mgr)
{
    std::string passwd;
    bool should_save_passwd = false;
    if( !_net_mgr.GetPassword(connection, passwd) ) {
        if( !_net_mgr.AskForPassword(connection, passwd) )
            return;
        should_save_passwd = true;
    }

    if( connection.IsType<NetworkConnectionsManager::FTP>() )
        dispatch_to_background([=, &_net_mgr] {
            auto activity = [_target registerExtActivity];
            const bool success = GoToFTP(_target, connection, passwd, _net_mgr);
            if( success && should_save_passwd )
                _net_mgr.SetPassword(connection, passwd);
        });
    else if( connection.IsType<NetworkConnectionsManager::SFTP>() )
        dispatch_to_background([=, &_net_mgr] {
            auto activity = [_target registerExtActivity];
            const bool success = GoToSFTP(_target, connection, passwd, _net_mgr);
            if( success && should_save_passwd )
                _net_mgr.SetPassword(connection, passwd);
        });
    else if( connection.IsType<NetworkConnectionsManager::LANShare>() )
        GoToLANShare(_target, connection, passwd, should_save_passwd, _net_mgr);
    else if( connection.IsType<NetworkConnectionsManager::Dropbox>() )
        dispatch_to_background([=, &_net_mgr] {
            auto activity = [_target registerExtActivity];
            GoToDropboxStorage(_target, connection, passwd, _net_mgr);
        });
    else if( connection.IsType<NetworkConnectionsManager::WebDAV>() )
        dispatch_to_background([=, &_net_mgr] {
            auto activity = [_target registerExtActivity];
            const bool success = GoToWebDAV(_target, connection, passwd, _net_mgr);
            if( success && should_save_passwd )
                _net_mgr.SetPassword(connection, passwd);
        });
}

OpenNetworkConnections::OpenNetworkConnections(NetworkConnectionsManager &_net_mgr) : OpenConnectionBase(_net_mgr)
{
}

void OpenNetworkConnections::Perform(PanelController *_target, id /*_sender*/) const
{
    const auto sheet = [[ConnectToServer alloc] initWithNetworkConnectionsManager:m_NetMgr];
    const auto window = _target.window;
    [sheet beginSheetForWindow:window
             completionHandler:^(NSModalResponse returnCode) {
               if( returnCode != NSModalResponseOK )
                   return;
               if( !sheet.connection )
                   return;
               GoToConnection(_target, *sheet.connection, m_NetMgr);
             }];
}

OpenExistingNetworkConnection::OpenExistingNetworkConnection(NetworkConnectionsManager &_net_mgr)
    : OpenConnectionBase(_net_mgr)
{
}

void OpenExistingNetworkConnection::Perform(PanelController *_target, id _sender) const
{
    AnyHolder *holder = nil;
    if( auto menuitem = objc_cast<NSMenuItem>(_sender) )
        holder = objc_cast<AnyHolder>(menuitem.representedObject);
    else if( auto command = objc_cast<NCCommandPopoverItem>(_sender) )
        holder = objc_cast<AnyHolder>(command.representedObject);

    if( holder ) {
        if( auto conn = std::any_cast<NetworkConnectionsManager::Connection>(&holder.any) ) {
            GoToConnection(_target, *conn, m_NetMgr);
        }
    }
}

} // namespace nc::panel::actions
