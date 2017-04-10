#include <Habanero/CommonPaths.h>
#include <Habanero/algo.h>
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <VFS/PS.h>
#include <VFS/NetFTP.h>
#include <VFS/NetSFTP.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Operations/Copy/FileCopyOperation.h>
#include <NimbleCommander/Operations/BatchRename/BatchRename.h>
#include <NimbleCommander/Operations/BatchRename/BatchRenameSheetController.h>
#include <NimbleCommander/Operations/BatchRename/BatchRenameOperation.h>
#include <NimbleCommander/Operations/CreateDirectory/CreateDirectorySheetController.h>
#include <NimbleCommander/Operations/CreateDirectory/CreateDirectoryOperation.h>
#include <NimbleCommander/Operations/Attrs/FileSysAttrChangeOperation.h>
#include <NimbleCommander/Operations/Attrs/FileSysEntryAttrSheetController.h>
#include <NimbleCommander/Operations/Attrs/FileSysAttrChangeOperationCommand.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include "PanelController+Menu.h"
#include "MainWindowFilePanelState.h"
#include <NimbleCommander/States/FilePanels/PanelDataPersistency.h>
#include <NimbleCommander/States/FilePanels/FavoritesMenuDelegate.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/Operations/Delete/FileDeletionSheetController.h>
#include "Views/FTPConnectionSheetController.h"
#include "Views/SFTPConnectionSheetController.h"
#include "Views/NetworkShareSheetController.h"
#include <NimbleCommander/Core/FileMask.h>
#include "Views/SelectionWithMaskPopupViewController.h"
#include <NimbleCommander/Core/ConnectionsMenuDelegate.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include "PanelAux.h"
#include "Actions/CopyFilePaths.h"
#include "Actions/AddToFavorites.h"
#include "Actions/GoToFolder.h"
#include "Actions/EjectVolume.h"
#include "Actions/ShowVolumeInformation.h"
#include "Actions/InsertFromPasteboard.h"
#include "Actions/OpenXAttr.h"
#include "Actions/CalculateChecksum.h"
#include "Actions/SpotlightSearch.h"
#include "Actions/OpenWithExternalEditor.h"
#include "Actions/ToggleSort.h"
#include "Actions/FindFiles.h"
#include "Actions/ShowGoToPopup.h"

static vector<VFSListingItem> DirectoriesWithoutDodDotInSortedOrder( const PanelData &_data )
{
    vector<VFSListingItem> items;
    for( auto ind: _data.SortedDirectoryEntries() )
        if( auto e = _data.EntryAtRawPosition(ind) )
            if( e.IsDir() && !e.IsDotDot() )
                items.emplace_back( move(e) );
    return items;
}

@implementation PanelController (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    try
    {
        return [self validateMenuItemImpl:item];
    }
    catch(exception &e)
    {
        cout << "Exception caught: " << e.what() << endl;
    }
    catch(...)
    {
        cout << "Caught an unhandled exception!" << endl;
    }
    return false;
}

- (BOOL) validateMenuItemImpl:(NSMenuItem *)item
{
    auto update_layout_item = [&](int _index)->bool{
        static auto &storage = AppDelegate.me.panelLayouts;
        item.state = self.layoutIndex == _index;
        if( auto l = storage.GetLayout(_index) )
            return !l->is_disabled();
        return false;
    };
    
#define TAG(name, str) static const int name = ActionsShortcutsManager::Instance().TagFromAction(str)
    TAG(tag_layout_1,           "menu.view.toggle_layout_1");
    TAG(tag_layout_2,           "menu.view.toggle_layout_2");
    TAG(tag_layout_3,           "menu.view.toggle_layout_3");
    TAG(tag_layout_4,           "menu.view.toggle_layout_4");
    TAG(tag_layout_5,           "menu.view.toggle_layout_5");
    TAG(tag_layout_6,           "menu.view.toggle_layout_6");
    TAG(tag_layout_7,           "menu.view.toggle_layout_7");
    TAG(tag_layout_8,           "menu.view.toggle_layout_8");
    TAG(tag_layout_9,           "menu.view.toggle_layout_9");
    TAG(tag_layout_10,          "menu.view.toggle_layout_10");
#undef TAG
    
    auto tag = item.tag;
#define IF(a) else if(tag == a)
    if(false);
    IF(tag_layout_1)        return update_layout_item(0);
    IF(tag_layout_2)        return update_layout_item(1);
    IF(tag_layout_3)        return update_layout_item(2);
    IF(tag_layout_4)        return update_layout_item(3);
    IF(tag_layout_5)        return update_layout_item(4);
    IF(tag_layout_6)        return update_layout_item(5);
    IF(tag_layout_7)        return update_layout_item(6);
    IF(tag_layout_8)        return update_layout_item(7);
    IF(tag_layout_9)        return update_layout_item(8);
    IF(tag_layout_10)       return update_layout_item(9);
#undef IF
    
    using namespace panel::actions;
#define VALIDATE(type) type::ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.file.find")                       return VALIDATE(FindFiles);
    IF_MENU_TAG("menu.file.calculate_sizes")            return m_View.item;
    IF_MENU_TAG("menu.file.add_to_favorites")           return VALIDATE(AddToFavorites);
    IF_MENU_TAG("menu.file.calculate_checksum")         return VALIDATE(CalculateChecksum);
    IF_MENU_TAG("menu.file.new_folder")                 return self.isUniform && self.vfs->IsWriteable();
    IF_MENU_TAG("menu.file.new_folder_with_selection")  return self.isUniform && self.vfs->IsWriteable() && m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.edit.paste")                      return VALIDATE(PasteFromPasteboard);
    IF_MENU_TAG("menu.edit.move_here")                  return VALIDATE(MoveFromPasteboard);
    IF_MENU_TAG("menu.view.sorting_by_name")            return VALIDATE(ToggleSortingByName);
    IF_MENU_TAG("menu.view.sorting_by_extension")       return VALIDATE(ToggleSortingByExtension);
    IF_MENU_TAG("menu.view.sorting_by_size")            return VALIDATE(ToggleSortingBySize);
    IF_MENU_TAG("menu.view.sorting_by_modify_time")     return VALIDATE(ToggleSortingByModifiedTime);
    IF_MENU_TAG("menu.view.sorting_by_creation_time")   return VALIDATE(ToggleSortingByCreatedTime);
    IF_MENU_TAG("menu.view.sorting_by_added_time")      return VALIDATE(ToggleSortingByAddedTime);
    IF_MENU_TAG("menu.view.sorting_case_sensitive")     return VALIDATE(ToggleSortingCaseSensitivity);
    IF_MENU_TAG("menu.view.sorting_separate_folders")   return VALIDATE(ToggleSortingFoldersSeparation);
    IF_MENU_TAG("menu.view.sorting_numeric_comparison") return VALIDATE(ToggleSortingNumerical);
    IF_MENU_TAG("menu.view.sorting_view_hidden")        return VALIDATE(ToggleSortingShowHidden);
    IF_MENU_TAG("menu.go.back")                         return m_History.CanMoveBack() || (!self.isUniform && !m_History.Empty());
    IF_MENU_TAG("menu.go.forward")                      return m_History.CanMoveForth();
    IF_MENU_TAG("menu.go.enclosing_folder")             return self.currentDirectoryPath != "/" || (self.isUniform && self.vfs->Parent() != nullptr);
    IF_MENU_TAG("menu.go.into_folder")                  return m_View.item && !m_View.item.IsDotDot();
    IF_MENU_TAG("menu.command.file_attributes")         return m_View.item && ( (!m_View.item.IsDotDot() && m_View.item.Host()->IsNativeFS()) || m_Data.Stats().selected_entries_amount > 0 );
    IF_MENU_TAG("menu.command.volume_information")      return VALIDATE(ShowVolumeInformation);
    IF_MENU_TAG("menu.command.internal_viewer")         return m_View.item && !m_View.item.IsDir();
    IF_MENU_TAG("menu.command.external_editor")         return VALIDATE(OpenWithExternalEditor);
    IF_MENU_TAG("menu.command.eject_volume")            return VALIDATE(EjectVolume);
    IF_MENU_TAG("menu.command.quick_look")              return m_View.item && !self.state.anyPanelCollapsed;
    IF_MENU_TAG("menu.command.system_overview")         return !self.state.anyPanelCollapsed;
    IF_MENU_TAG("menu.command.copy_file_name")          return VALIDATE(CopyFileName);
    IF_MENU_TAG("menu.command.copy_file_path")          return VALIDATE(CopyFilePath);
    IF_MENU_TAG("menu.command.move_to_trash")           return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.delete")                  return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.delete_permanently")      return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.create_directory")        return self.isUniform && self.vfs->IsWriteable();
    IF_MENU_TAG("menu.command.batch_rename")            return (!self.isUniform || self.vfs->IsWriteable()) && m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.open_xattr")              return VALIDATE(OpenXAttr);
#undef VALIDATE
    
    return true;
}

- (IBAction)OnGoBack:(id)sender {
    if( self.isUniform ) {
        if(!m_History.CanMoveBack())
            return;
        m_History.MoveBack();
    }
    else {
        // a different logic here, since non-uniform listings like search results (and temporary panels later) are not written into history
        if( m_History.Empty() )
            return;
        m_History.RewindAt( m_History.Length()-1 );
    }
    [self GoToVFSPromise:m_History.Current()->vfs
                  onPath:m_History.Current()->path];
}

- (IBAction)OnGoForward:(id)sender {
    if(!m_History.CanMoveForth())
        return;
    m_History.MoveForth();
    [self GoToVFSPromise:m_History.Current()->vfs
                  onPath:m_History.Current()->path];
}

- (IBAction)OnGoToHome:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Home()])
        return;
    [self GoToDir:CommonPaths::Home() vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToDocuments:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Documents()])
        return;
    [self GoToDir:CommonPaths::Documents() vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToDesktop:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Desktop()])
        return;
    [self GoToDir:CommonPaths::Desktop() vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToDownloads:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Downloads()])
        return;
    [self GoToDir:CommonPaths::Downloads() vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToApplications:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Applications()])
        return;
    [self GoToDir:CommonPaths::Applications() vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToUtilities:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Utilities()])
        return;
    [self GoToDir:CommonPaths::Utilities() vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToLibrary:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Library()])
        return;
    [self GoToDir:CommonPaths::Library() vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToRoot:(id)sender {
    if(![self ensureCanGoToNativeFolderSync:CommonPaths::Root()])
        return;
    [self GoToDir:CommonPaths::Root() vfs:VFSNativeHost::SharedHost() select_entry:"" async:true];
}

- (IBAction)OnGoToProcessesList:(id)sender {
    [self GoToDir:"/" vfs:VFSPSHost::GetSharedOrNew() select_entry:"" async:true];
}

- (IBAction)OnGoToFolder:(id)sender
{
    panel::actions::GoToFolder::Perform(self, sender);
}

- (IBAction)OnGoToUpperDirectory:(id)sender
{ // cmd+up
    [self HandleGoToUpperDirectory];
}

- (IBAction)OnGoIntoDirectory:(id)sender
{ // cmd+down
    auto item = m_View.item;
    if( item && !item.IsDotDot() )
        [self handleGoIntoDirOrArchiveSync:false];
}

- (bool) GoToFTPWithConnection:(NetworkConnectionsManager::Connection)_connection
                      password:(const string&)_passwd
{
    dispatch_assert_background_queue();    
    auto &info = _connection.Get<NetworkConnectionsManager::FTPConnection>();
    try {
        auto host = make_shared<VFSNetFTPHost>(info.host,
                                               info.user,
                                               _passwd,
                                               info.path,
                                               info.port
                                               );
        dispatch_to_main_queue([=]{
            m_DirectoryLoadingQ.Wait(); // just to be sure that GoToDir will not exit immed due to non-empty loading que
            [self GoToDir:info.path vfs:host select_entry:"" async:true];
        });
        
        // save successful connection usage to history
        NetworkConnectionsManager::Instance().ReportUsage(_connection);
        
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

- (void) showGoToFTPSheet:(optional<NetworkConnectionsManager::Connection>)_current
{
    FTPConnectionSheetController *sheet = [FTPConnectionSheetController new];
    if(_current)
        [sheet fillInfoFromStoredConnection:*_current];
    [sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode != NSModalResponseOK || sheet.server == nil)
            return;
        
        auto connection = sheet.result;
        string password = sheet.password ? sheet.password.UTF8String : "";
        NetworkConnectionsManager::Instance().InsertConnection(connection);
        NetworkConnectionsManager::Instance().SetPassword(connection, password);
        m_DirectoryLoadingQ.Run([=]{
            [self GoToFTPWithConnection:connection password:password];
        });
    }];
    
}

- (IBAction) OnGoToFTP:(id)sender
{
    [self showGoToFTPSheet:nullopt];
}

- (bool) GoToSFTPWithConnection:(NetworkConnectionsManager::Connection)_connection
                       password:(const string&)_passwd
{
    dispatch_assert_background_queue();
    auto &info = _connection.Get<NetworkConnectionsManager::SFTPConnection>();
    try {
        auto host = make_shared<VFSNetSFTPHost>(info.host,
                                                info.user,
                                                _passwd,
                                                info.keypath,
                                                info.port
                                                );
        dispatch_to_main_queue([=]{
            m_DirectoryLoadingQ.Wait(); // just to be sure that GoToDir will not exit immed due to non-empty loading que
            [self GoToDir:host->HomeDir() vfs:host select_entry:"" async:true];
        });
        
        // save successful connection to history
        NetworkConnectionsManager::Instance().ReportUsage(_connection);

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

- (void) showGoToSFTPSheet:(optional<NetworkConnectionsManager::Connection>)_current
{
    SFTPConnectionSheetController *sheet = [SFTPConnectionSheetController new];
    if(_current)
        [sheet fillInfoFromStoredConnection:*_current];
    [sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode != NSModalResponseOK)
            return;
        
        auto connection = sheet.result;
        string password = sheet.password ? sheet.password.UTF8String : "";
        NetworkConnectionsManager::Instance().InsertConnection(connection);
        NetworkConnectionsManager::Instance().SetPassword(connection, password);
        m_DirectoryLoadingQ.Run([=]{
            [self GoToSFTPWithConnection:connection password:password];
        });
    }];
    
}

- (IBAction) OnGoToSFTP:(id)sender
{
    [self showGoToSFTPSheet:nullopt];
}

- (void) GoToLANShareWithConnection:(NetworkConnectionsManager::Connection)_connection
                           password:(const string&)_passwd
                       savePassword:(bool)_save_password_on_success
{
    auto activity = make_shared<panel::ActivityTicket>();
    __weak PanelController *weak_self = self;
    auto cb = [weak_self, activity, _connection, _passwd, _save_password_on_success]
        (const string &_path, const string &_err) {
        if( PanelController *panel = weak_self ) {
            if( !_path.empty() ) {
                [panel GoToDir:_path
                           vfs:VFSNativeHost::SharedHost()
                  select_entry:""
                         async:true];
                
                // save successful connection to history
                NetworkConnectionsManager::Instance().ReportUsage(_connection);
                if( _save_password_on_success )
                    NetworkConnectionsManager::Instance().SetPassword(_connection, _passwd);
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
    
    auto &ncm = NetworkConnectionsManager::Instance();
    if( ncm.MountShareAsync(_connection, _passwd, cb) )
        *activity = [self registerExtActivity];
}

- (void) showGoToNetworkShareSheet:(optional<NetworkConnectionsManager::Connection>)_current
{
    NetworkShareSheetController *sheet = _current ?
        [[NetworkShareSheetController alloc] initWithConnection:*_current] :
        [[NetworkShareSheetController alloc] init];

    [sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode != NSModalResponseOK)
            return;
        
        auto connection = sheet.connection;
        auto password = string(sheet.providedPassword.UTF8String);
        NetworkConnectionsManager::Instance().InsertConnection(connection);
        NetworkConnectionsManager::Instance().SetPassword(connection, password);
        [self GoToLANShareWithConnection:connection password:password savePassword:false];
    }];
}

- (IBAction) OnGoToNetworkShare:(id)sender
{
    [self showGoToNetworkShareSheet:nullopt];
}

- (void)GoToSavedConnection:(NetworkConnectionsManager::Connection)connection
{
    auto &ncm = NetworkConnectionsManager::Instance();
    string passwd;
    bool should_save_passwd = false;
    if( !ncm.GetPassword(connection, passwd) ) {
        if( !ncm.AskForPassword(connection, passwd) )
            return;
        should_save_passwd = true;
    }
    
    if( connection.IsType<NetworkConnectionsManager::FTPConnection>() )
        m_DirectoryLoadingQ.Run([=]{
            bool success = [self GoToFTPWithConnection:connection password:passwd];
            if( success && should_save_passwd )
                 NetworkConnectionsManager::Instance().SetPassword(connection, passwd);
        });
    else if( connection.IsType<NetworkConnectionsManager::SFTPConnection>() )
        m_DirectoryLoadingQ.Run([=]{
            bool success = [self GoToSFTPWithConnection:connection password:passwd];
            if( success && should_save_passwd )
                 NetworkConnectionsManager::Instance().SetPassword(connection, passwd);
        });
    else if( connection.IsType<NetworkConnectionsManager::LANShare>() ) {
        [self GoToLANShareWithConnection:connection
                                password:passwd
                            savePassword:should_save_passwd];
    }
}

- (IBAction)OnGoToQuickListsParents:(id)sender
{
    panel::actions::ShowParentFoldersQuickList::Perform(self, sender);
}

- (IBAction)OnGoToQuickListsHistory:(id)sender
{
    panel::actions::ShowHistoryQuickList::Perform(self, sender);
}

- (IBAction)OnGoToQuickListsVolumes:(id)sender
{
    panel::actions::ShowVolumesQuickList::Perform(self, sender);
}

- (IBAction)OnGoToQuickListsFavorites:(id)sender
{
    panel::actions::ShowFavoritesQuickList::Perform(self, sender);
}

- (IBAction)OnGoToQuickListsConnections:(id)sender
{
    panel::actions::ShowConnectionsQuickList::Perform(self, sender);
}

- (IBAction)OnGoToFavoriteLocation:(id)sender
{
    if( auto menuitem = objc_cast<NSMenuItem>(sender) )
        if( auto holder = objc_cast<AnyHolder>(menuitem.representedObject) )
            if( auto location = any_cast<PanelDataPersisency::Location>(&holder.any) )
                [self goToPersistentLocation:*location];
}

- (IBAction) OnGoToSavedConnectionItem:(id)sender
{
    if( auto menuitem = objc_cast<NSMenuItem>(sender) )
        if( auto rep = objc_cast<ConnectionsMenuDelegateInfoWrapper>(menuitem.representedObject) )
            [self GoToSavedConnection:rep.object];
}

- (IBAction) OnDeleteSavedConnectionItem:(id)sender
{
    if( auto menuitem = objc_cast<NSMenuItem>(sender) )
        if( auto rep = objc_cast<ConnectionsMenuDelegateInfoWrapper>(menuitem.representedObject) ) {
            Alert *alert = [[Alert alloc] init];
            alert.messageText = NSLocalizedString(@"Are you sure you want to delete this connection?", "Asking user if he really wants to delete information about a stored connection");
            alert.informativeText = NSLocalizedString(@"You can’t undo this action.", "");
            [alert addButtonWithTitle:NSLocalizedString(@"Yes", "")];
            [alert addButtonWithTitle:NSLocalizedString(@"No", "")];
            if([alert runModal] == NSAlertFirstButtonReturn)
                NetworkConnectionsManager::Instance().RemoveConnection(rep.object);
        }
}

- (IBAction)OnEditSavedConnectionItem:(id)sender
{
    if( auto menuitem = objc_cast<NSMenuItem>(sender) )
        if( auto rep = objc_cast<ConnectionsMenuDelegateInfoWrapper>(menuitem.representedObject) )  {
            auto conn = rep.object;
            if( conn.IsType<NetworkConnectionsManager::FTPConnection>() )
                [self showGoToFTPSheet:conn];
            else if( conn.IsType<NetworkConnectionsManager::SFTPConnection>() )
                [self showGoToSFTPSheet:conn];
            else if( conn.IsType<NetworkConnectionsManager::LANShare>() )
                [self showGoToNetworkShareSheet:conn];
        }
}

- (IBAction)OnOpen:(id)sender { // enter
    [self handleGoIntoDirOrOpenInSystemSync];
}

- (IBAction)OnOpenNatively:(id)sender { // shift+enter
    [self handleOpenInSystem];
}

// when Operation.AddOnFinishHandler will use C++ lambdas - change return type here:
- (void (^)()) refreshCurrentControllerLambda
{
    __weak auto cur = self;
    auto update_this_panel = [=] {
        dispatch_to_main_queue( [=]{
            [(PanelController*)cur refreshPanel];
        });
    };
    return update_this_panel;
}

- (IBAction)OnFileAttributes:(id)sender {
    auto entries = to_shared_ptr(self.selectedEntriesOrFocusedEntry);
    if( entries->empty() )
        return;
    if( !all_of(begin(*entries), end(*entries), [](auto &i){ return i.Host()->IsNativeFS(); }) )
        return;
    
    FileSysEntryAttrSheetController *sheet = [[FileSysEntryAttrSheetController alloc] initWithItems:entries];
    [sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode == NSModalResponseOK ) {
            auto op = [[FileSysAttrChangeOperation alloc] initWithCommand:*sheet.result];
            if( !self.receivesUpdateNotifications )
                [op AddOnFinishHandler:self.refreshCurrentControllerLambda];
            [self.state AddOperation:op];
        }
    }];
}

- (IBAction)OnDetailedVolumeInformation:(id)sender
{
    panel::actions::ShowVolumeInformation::Perform(self, sender);
}

- (IBAction)onMainMenuPerformFindAction:(id)sender
{
    panel::actions::FindFiles::Perform(self, sender);
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender {
    if( auto i = self.view.item ) {
        if( i.IsDir() )
            return;
        [self.mainWindowController RequestBigFileView:i.Path() with_fs:i.Host()];
    }
}

- (void)DoSelectByMask:(bool)_select
{
    SelectionWithMaskPopupViewController *view = [[SelectionWithMaskPopupViewController alloc] initForWindow:self.state.window doesSelect:_select];
    view.handler = [=](NSString *mask) {
        if( !FileMask::IsWildCard(mask.UTF8String) )
            mask = [NSString stringWithUTF8StdString:FileMask::ToExtensionWildCard(mask.UTF8String)];
        
        [self SelectEntriesByMask:mask select:_select];
    };
    
    [self.view showPopoverUnderPathBarWithView:view andDelegate:view];
}

- (IBAction)OnSelectByMask:(id)sender {
    [self DoSelectByMask:true];
}

- (IBAction)OnDeselectByMask:(id)sender {
    [self DoSelectByMask:false];
}

- (void)DoQuickSelectByExtension:(bool)_select
{
    if( auto item = self.view.item )
        if( m_Data.CustomFlagsSelectAllSortedByExtension(item.HasExtension() ? item.Extension() : "", _select, self.ignoreDirectoriesOnSelectionByMask) )
           [m_View volatileDataChanged];
}

- (IBAction)OnQuickSelectByExtension:(id)sender
{
    [self DoQuickSelectByExtension:true];
}

- (IBAction)OnQuickDeselectByExtension:(id)sender
{
    [self DoQuickSelectByExtension:false];
}

- (IBAction)OnSpotlightSearch:(id)sender
{
    panel::actions::SpotlightSearch::Perform(self, sender);
}

- (IBAction)OnEjectVolume:(id)sender
{
    panel::actions::EjectVolume::Perform(self, sender);
}

- (IBAction)OnCopyCurrentFileName:(id)sender
{
    panel::actions::CopyFileName::Perform(self, sender);
}

- (IBAction)OnCopyCurrentFilePath:(id)sender
{
    panel::actions::CopyFilePath::Perform(self, sender);
}

- (IBAction)OnBriefSystemOverviewCommand:(id)sender
{
    if( m_BriefSystemOverview ) {
        [self.state CloseOverlay:self];
        m_BriefSystemOverview = nil;
        return;
    }
    
    m_BriefSystemOverview = [self.state RequestBriefSystemOverview:self];
    if( m_BriefSystemOverview )
        [self UpdateBriefSystemOverview];
}

- (IBAction)OnFileViewCommand:(id)sender
{
    // Close quick preview, if it is open.
    if( m_QuickLook ) {
        [self.state CloseOverlay:self];
        m_QuickLook = nil;
        return;
    }
    
    m_QuickLook = [self.state RequestQuickLookView:self];
    if( m_QuickLook )
        [self OnCursorChanged];
}

- (void)selectAll:(id)sender
{
    [self SelectAllEntries:true];
}

- (void)deselectAll:(id)sender
{
    [self SelectAllEntries:false];
}

- (IBAction)OnMenuInvertSelection:(id)sender
{
    [self invertSelection];
}

- (IBAction)OnRefreshPanel:(id)sender
{
    [self forceRefreshPanel];
}

- (IBAction)OnCalculateSizes:(id)sender
{
    // suboptimal - may have regular files inside (not dirs)
    [self CalculateSizes:self.selectedEntriesOrFocusedEntryWithDotDot];
}

- (IBAction)OnCalculateAllSizes:(id)sender
{
    [self CalculateSizes:DirectoriesWithoutDodDotInSortedOrder(self.data)];
}

- (IBAction)ToggleViewHiddenFiles:(id)sender
{
    panel::actions::ToggleSortingShowHidden::Perform(self, sender);
}

- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender
{
    panel::actions::ToggleSortingFoldersSeparation::Perform(self, sender);
}

- (IBAction)ToggleCaseSensitiveComparison:(id)sender
{
    panel::actions::ToggleSortingCaseSensitivity::Perform(self, sender);
}

- (IBAction)ToggleNumericComparison:(id)sender
{
    panel::actions::ToggleSortingNumerical::Perform(self, sender);
}

- (IBAction)ToggleSortByName:(id)sender
{
    panel::actions::ToggleSortingByName::Perform(self, sender);
}

- (IBAction)ToggleSortByExt:(id)sender
{
    panel::actions::ToggleSortingByExtension::Perform(self, sender);
}

- (IBAction)ToggleSortByMTime:(id)sender
{
    panel::actions::ToggleSortingByModifiedTime::Perform(self, sender);
}

- (IBAction)ToggleSortBySize:(id)sender
{
    panel::actions::ToggleSortingBySize::Perform(self, sender);
}

- (IBAction)ToggleSortByBTime:(id)sender
{
    panel::actions::ToggleSortingByCreatedTime::Perform(self, sender);
}

- (IBAction)ToggleSortByATime:(id)sender
{
    panel::actions::ToggleSortingByAddedTime::Perform(self, sender);
}

// deliberately chosen the most dumb way to introduce ten different options:
- (IBAction)onToggleViewLayout1:(id)sender { [self setLayoutIndex:0]; }
- (IBAction)onToggleViewLayout2:(id)sender { [self setLayoutIndex:1]; }
- (IBAction)onToggleViewLayout3:(id)sender { [self setLayoutIndex:2]; }
- (IBAction)onToggleViewLayout4:(id)sender { [self setLayoutIndex:3]; }
- (IBAction)onToggleViewLayout5:(id)sender { [self setLayoutIndex:4]; }
- (IBAction)onToggleViewLayout6:(id)sender { [self setLayoutIndex:5]; }
- (IBAction)onToggleViewLayout7:(id)sender { [self setLayoutIndex:6]; }
- (IBAction)onToggleViewLayout8:(id)sender { [self setLayoutIndex:7]; }
- (IBAction)onToggleViewLayout9:(id)sender { [self setLayoutIndex:8]; }
- (IBAction)onToggleViewLayout10:(id)sender{ [self setLayoutIndex:9]; }

- (IBAction)OnOpenWithExternalEditor:(id)sender
{
    panel::actions::OpenWithExternalEditor::Perform(self, sender);
}

- (void)DeleteFiles:(bool)_delete_permanently
{
    auto items = to_shared_ptr(self.selectedEntriesOrFocusedEntry);
    if( items->empty() )
        return;

    unordered_set<string> dirs;
    bool all_native = all_of(begin(*items), end(*items), [&](auto &i){
        if( !i.Host()->IsNativeFS() )
            return false;
        dirs.emplace( i.Directory() );
        return true;
    });
    
    FileDeletionSheetController *sheet = [[FileDeletionSheetController alloc] initWithItems:items];
    if( all_native ) {
        bool all_have_trash = all_of(begin(dirs), end(dirs), [](auto &i){
            if( auto vol = NativeFSManager::Instance().VolumeFromPath(i) )
                if( vol->interfaces.has_trash )
                    return true;
            return false;
        });
        
        sheet.allowMoveToTrash = all_have_trash;
        sheet.defaultType = _delete_permanently ?
            FileDeletionOperationType::Delete :
            (sheet.allowMoveToTrash ? FileDeletionOperationType::MoveToTrash : FileDeletionOperationType::Delete);
    }
    else {
        sheet.allowMoveToTrash = false;
        sheet.defaultType = FileDeletionOperationType::Delete;
    }

    [sheet beginSheetForWindow:self.window
             completionHandler:^(NSModalResponse returnCode) {
                 if(returnCode == NSModalResponseOK){
                     FileDeletionOperation *op = [[FileDeletionOperation alloc] initWithFiles:move(*items)
                                                                                         type:sheet.resultType];
                     if( !self.receivesUpdateNotifications )
                         [op AddOnFinishHandler:self.refreshCurrentControllerLambda];
                     [self.state AddOperation:op];
                 }
             }];
}

- (IBAction)OnDeleteCommand:(id)sender
{
    [self DeleteFiles:false];
}

- (IBAction)OnDeletePermanentlyCommand:(id)sender
{
    [self DeleteFiles:true];
}

- (IBAction)OnMoveToTrash:(id)sender
{
    auto items = self.selectedEntriesOrFocusedEntry;
    unordered_set<string> dirs;
    bool all_native = all_of(begin(items), end(items), [&](auto &i){
        if( !i.Host()->IsNativeFS() )
            return false;
        dirs.emplace( i.Directory() );
        return true;
    });
    
    if( !all_native ) {
        // instead of trying to silently reap files on VFS like FTP (that means we'll erase it, not move to trash) -
        // forward request as a regular F8 delete
        [self OnDeleteCommand:self];
        return;
    }

    bool all_have_trash = all_of(begin(dirs), end(dirs), [](auto &i){
        if( auto vol = NativeFSManager::Instance().VolumeFromPath(i) )
            if( vol->interfaces.has_trash )
                return true;
        return false;
    });
    
    if( !all_have_trash ) {
        // if user called MoveToTrash by cmd+backspace but there's no trash on this volume:
        // show a dialog and ask him to delete a file permanently
        [self OnDeleteCommand:self];
        return;
    }
    
    FileDeletionOperation *op = [[FileDeletionOperation alloc] initWithFiles:move(items)
                                                                        type:FileDeletionOperationType::MoveToTrash];
    if( !self.receivesUpdateNotifications )
        [op AddOnFinishHandler:self.refreshCurrentControllerLambda];
    
    [self.state AddOperation:op];
}

- (IBAction)OnCreateDirectoryCommand:(id)sender
{
    CreateDirectorySheetController *cd = [CreateDirectorySheetController new];
    [cd beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
         if( returnCode == NSModalResponseOK && !cd.result.empty() ) {
             string pdir = m_Data.DirectoryPathWithoutTrailingSlash();
             
             CreateDirectoryOperation *op = [CreateDirectoryOperation alloc];
             if(self.vfs->IsNativeFS())
                 op = [op initWithPath:cd.result.c_str() rootpath:pdir.c_str()];
             else
                 op = [op initWithPath:cd.result.c_str() rootpath:pdir.c_str() at:self.vfs];
             op.TargetPanel = self;
             [self.state AddOperation:op];
         }
     }];
}

- (IBAction)OnCalculateChecksum:(id)sender
{
    return panel::actions::CalculateChecksum::Perform(self, sender);
}

- (IBAction)OnQuickNewFolder:(id)sender
{
    NSString *stub = NSLocalizedString(@"untitled folder", "Name for freshly create folder by hotkey");
    path dir = self.currentDirectoryPath;
    string name = stub.fileSystemRepresentationSafe;
    
    // currently doing existance checking in main thread, which is bad for a slow remote vfs
    // better implement it asynchronously.
    if( self.vfs->Exists((dir/name).c_str()) )
        // this file already exists, will try another ones
        for( int i = 2; ; ++i ) {
            name = [NSString stringWithFormat:@"%@ %i", stub, i].fileSystemRepresentationSafe;
            if( !self.vfs->Exists((dir/name).c_str()) )
                break;
            if( i >= 100 )
                return; // we're full of such filenames, no reason to go on
        }

    CreateDirectoryOperation *op = [CreateDirectoryOperation alloc];
    if(self.vfs->IsNativeFS())
        op = [op initWithPath:name.c_str() rootpath:dir.c_str()];
    else
        op = [op initWithPath:name.c_str() rootpath:dir.c_str() at:self.vfs];
    
    bool force_reload = self.vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
    __weak PanelController *ws = self;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    [op AddOnFinishHandler:^{
        dispatch_to_main_queue([=]{
            PanelController *ss = ws;
            
            if(force_reload)
                [ss refreshPanel];
            
            PanelControllerDelayedSelection req;
            req.filename = name;
            req.timeout = 2s;
            req.done = [=]{
                [((PanelController*)ws).view startFieldEditorRenaming];
            };
            [ss ScheduleDelayedSelectionChangeFor:req];
        });
    }];
#pragma clang diagnostic pop
    
    [self.state AddOperation:op];
}

- (IBAction)OnQuickNewFolderWithSelection:(id)sender
{
    if( !self.isUniform )
        return;
    
    auto files = self.selectedEntriesOrFocusedEntry;
    if(files.empty())
        return;
    NSString *stub = NSLocalizedString(@"New Folder with Items", "Name for freshly created folder by hotkey with items");
    string name = stub.fileSystemRepresentationSafe;
    path dir = self.currentDirectoryPath;
    
    // currently doing existance checking in main thread, which is bad for a slow remote vfs
    // better implement it asynchronously.
    if( self.vfs->Exists((dir/name).c_str()) )
        // this file already exists, will try another ones
        for( int i = 2; ; ++i ) {
            name = [NSString stringWithFormat:@"%@ %i", stub, i].fileSystemRepresentationSafe;
            if( !self.vfs->Exists((dir/name).c_str()) )
                break;
            if( i >= 100 )
                return; // we're full of such filenames, no reason to go on
        }
    
    path src = self.currentDirectoryPath;
    path dst = src / name / "/";
    
    FileCopyOperationOptions opts = panel::MakeDefaultFileMoveOptions();
    auto op = [[FileCopyOperation alloc] initWithItems:files destinationPath:dst.native() destinationHost:self.vfs options:opts];

    bool force_reload = self.vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
    __weak PanelController *ws = self;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    [op AddOnFinishHandler:^{
        dispatch_to_main_queue([=]{
            PanelController *ss = ws;
            
            if(force_reload)
                [ss refreshPanel];
            
            PanelControllerDelayedSelection req;
            req.filename = name;
            req.timeout = 2s;            
            req.done = [=]{
                dispatch_to_main_queue([=]{
                    [((PanelController*)ws).view startFieldEditorRenaming];
                });
            };
            [ss ScheduleDelayedSelectionChangeFor:req];
        });
    }];
#pragma clang diagnostic pop
    
    [self.state AddOperation:op];
}

- (IBAction)OnQuickNewFile:(id)sender
{
    path dir = self.currentDirectoryPath;
    VFSHostPtr vfs = self.vfs;
    bool force_reload = self.vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
    __weak PanelController *ws = self;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-repeated-use-of-weak"
    
    dispatch_to_background([=]{
        NSString *stub = NSLocalizedString(@"untitled.txt", "Name for freshly created file by hotkey");
        string name = stub.fileSystemRepresentationSafe;
        
        if( self.vfs->Exists((dir/name).c_str()) )
            // this file already exists, will try another ones
            for( int i = 2; ; ++i ) {
                path p = stub.fileSystemRepresentationSafe;
                if( p.has_extension() ) {
                    auto ext = p.extension();
                    p.replace_extension();
                    name = p.native() + " " + to_string(i) + ext.native();
                }
                else
                    name = p.native() + " " + to_string(i);
                
                if( !self.vfs->Exists( (dir/name).c_str() ) )
                    break;
                if( i >= 100 )
                    return; // we're full of such filenames, no reason to go on
            }
        
        auto path = dir / name;
        int ret = VFSEasyCreateEmptyFile(path.c_str(), vfs);
        if( ret != 0)
            return dispatch_to_main_queue([=]{
                Alert *alert = [[Alert alloc] init];
                alert.messageText = NSLocalizedString(@"Failed to create an empty file:", "Showing error when trying to create an empty file");
                alert.informativeText = VFSError::ToNSError(ret).localizedDescription;
                [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
                [alert runModal];
            });
        
        dispatch_to_main_queue([=]{
            PanelController *ss = ws;
            
            if(force_reload)
                [ss refreshPanel];
            
            PanelControllerDelayedSelection req;
            req.filename = name;
            req.timeout = 2s;
            req.done = [=]{
                dispatch_to_main_queue([=]{
                    [((PanelController*)ws).view startFieldEditorRenaming];
                });
            };
            [ss ScheduleDelayedSelectionChangeFor:req];
        });
    });
#pragma clang diagnostic pop
}

- (IBAction)OnBatchRename:(id)sender
{
    auto items = self.selectedEntriesOrFocusedEntry;
    if( items.empty() )
        return;
    
    auto host = items.front().Host();
    if( !all_of(begin(items), end(items), [=](auto &i){ return i.Host() == host;}) )
        return; // currently BatchRenameOperation supports only single host for items    
    
    BatchRenameSheetController *sheet = [[BatchRenameSheetController alloc] initWithItems:move(items)];
    [sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if(returnCode == NSModalResponseOK) {
            auto src_paths = sheet.filenamesSource;
            auto dst_paths = sheet.filenamesDestination;
            BatchRenameOperation *op = [[BatchRenameOperation alloc] initWithOriginalFilepaths:move(src_paths)
                                                                              renamedFilepaths:move(dst_paths)
                                                                                           vfs:host];
            if( !self.receivesUpdateNotifications )
                [op AddOnFinishHandler:self.refreshCurrentControllerLambda];            
            [self.state AddOperation:op];
        }
    }];    
}

- (IBAction) OnOpenExtendedAttributes:(id)sender
{
    panel::actions::OpenXAttr::Perform(self, sender);
}

- (IBAction) OnRenameFileInPlace:(id)sender
{
    [self.view startFieldEditorRenaming];
}

- (IBAction) OnAddToFavorites:(id)sender
{
    panel::actions::AddToFavorites::Perform(self, sender);
}

- (IBAction)copy:(id)sender
{
    [self writeFilesnamesPBoard:NSPasteboard.generalPasteboard];
}

- (IBAction)paste:(id)sender
{
    panel::actions::PasteFromPasteboard::Perform(self, sender);
}

- (IBAction)moveItemHere:(id)sender
{
    panel::actions::MoveFromPasteboard::Perform(self, sender);
}

@end
