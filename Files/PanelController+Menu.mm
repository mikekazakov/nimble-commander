//
//  PanelController+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 24.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/CommonPaths.h>
#include <Habanero/algo.h>
#include <Utility/NativeFSManager.h>
#include "vfs/VFSListingInput.h"
#include "vfs/vfs_native.h"
#include "vfs/vfs_ps.h"
#include "vfs/vfs_net_ftp.h"
#include "vfs/vfs_net_sftp.h"
#include "vfs/vfs_xattr.h"
#include "Operations/Copy/FileCopyOperation.h"
#include "Operations/BatchRename/BatchRename.h"
#include "Operations/BatchRename/BatchRenameSheetController.h"
#include "Operations/BatchRename/BatchRenameOperation.h"
#include "Operations/CreateDirectory/CreateDirectorySheetController.h"
#include "Operations/CreateDirectory/CreateDirectoryOperation.h"
#include "Operations/Attrs/FileSysAttrChangeOperation.h"
#include "Operations/Attrs/FileSysEntryAttrSheetController.h"
#include "Operations/Attrs/FileSysAttrChangeOperationCommand.h"
#include "ExternalEditorInfo.h"
#include "ActionsShortcutsManager.h"
#include "PanelController+Menu.h"
#include "GoToFolderSheetController.h"
#include "MainWindowFilePanelState.h"
#include "DetailedVolumeInformationSheetController.h"
#include "FindFilesSheetController.h"
#include "MainWindowController.h"
#include "Operations/Delete/FileDeletionSheetController.h"
#include "FTPConnectionSheetController.h"
#include "SFTPConnectionSheetController.h"
#include "FileMask.h"
#include "SelectionWithMaskPopupViewController.h"
#include "PanelViewPresentation.h"
#include "CalculateChecksumSheetController.h"
#include "ConnectionsMenuDelegate.h"

static shared_ptr<VFSListing> FetchSearchResultsAsListing(const map<string, vector<string>> &_dir_to_filenames, VFSHostPtr _vfs, int _fetch_flags, VFSCancelChecker _cancel_checker)
{
    vector<shared_ptr<VFSListing>> listings;
    vector<vector<unsigned>> indeces;
    
    for(auto &directory: _dir_to_filenames) {
        shared_ptr<VFSListing> listing;
        if( _vfs->FetchFlexibleListing(directory.first.c_str(), listing, _fetch_flags, _cancel_checker) == 0) {
            listings.emplace_back(listing);
            indeces.emplace_back();
            auto &ind = indeces.back();
            
            unordered_map<string, unsigned> listing_fn_ind;
            for(unsigned i = 0, e = listing->Count(); i != e; ++i)
                listing_fn_ind[ listing->Filename(i) ] = i;
                
                for( auto &filename: directory.second ) {
                    auto it = listing_fn_ind.find(filename);
                    if( it != end(listing_fn_ind) )
                        ind.emplace_back( it->second );
                }
        }
    }
    
    return VFSListing::Build( VFSListing::Compose(listings, indeces) );
}

static void WriteSingleStringToClipboard(const string &_s)
{
    NSPasteboard *pb = NSPasteboard.generalPasteboard;
    [pb declareTypes:@[NSStringPboardType] owner:nil];
    [pb setString:[NSString stringWithUTF8StdString:_s] forType:NSStringPboardType];
}

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
    auto upd_for_sort = [](NSMenuItem * _item, PanelSortMode _mode, PanelSortMode::Mode _mask){
        static NSImage *img = [NSImage imageNamed:NSImageNameRemoveTemplate];
        if(_mode.sort & _mask) {
            _item.image = _mode.isrevert() ? img : nil;
            _item.state = NSOnState;
        }
        else {
            _item.image = nil;
            _item.state = NSOffState;
        }
    };
    
#define TAG(name, str) static const int name = ActionsShortcutsManager::Instance().TagFromAction(str)
    TAG(tag_short_mode,         "menu.view.toggle_short_mode");
    TAG(tag_medium_mode,        "menu.view.toggle_medium_mode");
    TAG(tag_full_mode,          "menu.view.toggle_full_mode");
    TAG(tag_wide_mode,          "menu.view.toggle_wide_mode");
    TAG(tag_sort_name,          "menu.view.sorting_by_name");
    TAG(tag_sort_ext,           "menu.view.sorting_by_extension");
    TAG(tag_sort_mod,           "menu.view.sorting_by_modify_time");
    TAG(tag_sort_size,          "menu.view.sorting_by_size");
    TAG(tag_sort_creat,         "menu.view.sorting_by_creation_time");
    TAG(tag_sort_viewhidden,    "menu.view.sorting_view_hidden");
    TAG(tag_sort_sepfolders,    "menu.view.sorting_separate_folders");
    TAG(tag_sort_casesens,      "menu.view.sorting_case_sensitive");
    TAG(tag_sort_numeric,       "menu.view.sorting_numeric_comparison");
#undef TAG
    
    auto tag = item.tag;
#define IF(a) else if(tag == a)
    if(false);
    IF(tag_short_mode)      item.state = m_View.type == PanelViewType::Short;
    IF(tag_medium_mode)     item.state = m_View.type == PanelViewType::Medium;
    IF(tag_full_mode)       item.state = m_View.type == PanelViewType::Full;
    IF(tag_wide_mode)       item.state = m_View.type == PanelViewType::Wide;
    IF(tag_sort_viewhidden) item.state = m_Data.HardFiltering().show_hidden;
    IF(tag_sort_sepfolders) item.state = m_Data.SortMode().sep_dirs;
    IF(tag_sort_casesens)   item.state = m_Data.SortMode().case_sens;
    IF(tag_sort_numeric)    item.state = m_Data.SortMode().numeric_sort;
    IF(tag_sort_name)       upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByNameMask);
    IF(tag_sort_ext)        upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByExtMask);
    IF(tag_sort_mod)        upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByMTimeMask);
    IF(tag_sort_size)       upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortBySizeMask);
    IF(tag_sort_creat)      upd_for_sort(item, m_Data.SortMode(), PanelSortMode::SortByBTimeMask);
#undef IF
    
    IF_MENU_TAG("menu.go.back")                         return m_History.CanMoveBack() || (!self.isUniform && !m_History.Empty());
    IF_MENU_TAG("menu.go.forward")                      return m_History.CanMoveForth();
    IF_MENU_TAG("menu.go.enclosing_folder")             return self.currentDirectoryPath != "/" || (self.isUniform && self.vfs->Parent() != nullptr);
    IF_MENU_TAG("menu.go.into_folder")                  return m_View.item && !m_View.item.IsDotDot();
    IF_MENU_TAG("menu.command.file_attributes")         return m_View.item && ( (!m_View.item.IsDotDot() && m_View.item.Host()->IsNativeFS()) || m_Data.Stats().selected_entries_amount > 0 );
    IF_MENU_TAG("menu.command.volume_information")      return !self.isUniform || self.vfs->IsNativeFS();
    IF_MENU_TAG("menu.command.internal_viewer")         return m_View.item && !m_View.item.IsDir();
    IF_MENU_TAG("menu.command.external_editor")         return m_View.item && !m_View.item.IsDotDot() && m_View.item.Host()->IsNativeFS();
    IF_MENU_TAG("menu.command.eject_volume")            return self.isUniform && self.vfs->IsNativeFS() && NativeFSManager::Instance().IsVolumeContainingPathEjectable(self.currentDirectoryPath);
    IF_MENU_TAG("menu.file.calculate_sizes")            return m_View.item;
    IF_MENU_TAG("menu.command.copy_file_name")          return m_View.item;
    IF_MENU_TAG("menu.command.copy_file_path")          return m_View.item;
    IF_MENU_TAG("menu.command.move_to_trash")           return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.delete")                  return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.delete_permanently")      return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.create_directory")        return self.isUniform && self.vfs->IsWriteable();
    IF_MENU_TAG("menu.file.calculate_checksum")         return m_View.item && (!m_View.item.IsDir() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.file.new_folder")                 return self.isUniform && self.vfs->IsWriteable();
    IF_MENU_TAG("menu.file.new_folder_with_selection")  return self.isUniform && self.vfs->IsWriteable() && m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.batch_rename")            return (!self.isUniform || self.vfs->IsWriteable()) && m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.open_xattr")              return m_View.item && m_View.item.Host()->IsNativeFS();
    
    return true; // will disable some items in the future
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
    [self GoToVFSPathStack:*m_History.Current()];
}

- (IBAction)OnGoForward:(id)sender {
    if(!m_History.CanMoveForth())
        return;
    m_History.MoveForth();
    [self GoToVFSPathStack:*m_History.Current()];
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

- (IBAction)OnGoToFolder:(id)sender {
    GoToFolderSheetController *sheet = [GoToFolderSheetController new];
    sheet.panel = self;
    [sheet showSheetWithParentWindow:self.window handler:[=]{
        
        auto c = make_shared<PanelControllerGoToDirContext>();
        c->RequestedDirectory = [self expandPath:sheet.requestedPath];
        c->VFS = self.vfs;
        c->PerformAsynchronous = true;
        c->LoadingResultCallback = [=](int _code) {
            dispatch_to_main_queue( [=]{
                [sheet tellLoadingResult:_code];
            });
        };

        // TODO: check reachability from sandbox        
        
        [self GoToDirWithContext:c];        
    }];
}

- (IBAction)OnGoToUpperDirectory:(id)sender { // cmd+up
    [self HandleGoToUpperDirectory];
}

- (IBAction)OnGoIntoDirectory:(id)sender { // cmd+down
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
            m_DirectoryLoadingQ->Wait(); // just to be sure that GoToDir will not exit immed due to non-empty loading que
            [self GoToDir:info.path vfs:host select_entry:"" async:true];
        });
        
        // save successful connection usage to history
        NetworkConnectionsManager::Instance().ReportUsage(_connection);
        
        return true;
    } catch (VFSErrorException &e) {
        dispatch_to_main_queue([=]{
            NSAlert *alert = [[NSAlert alloc] init];
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
        m_DirectoryLoadingQ->Run([=]{
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
            m_DirectoryLoadingQ->Wait(); // just to be sure that GoToDir will not exit immed due to non-empty loading que
            [self GoToDir:host->HomeDir() vfs:host select_entry:"" async:true];
        });
        
        // save successful connection to history
        NetworkConnectionsManager::Instance().ReportUsage(_connection);

        return true;
    } catch (const VFSErrorException &e) {
        dispatch_to_main_queue([=]{
            NSAlert *alert = [[NSAlert alloc] init];
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
        m_DirectoryLoadingQ->Run([=]{
            [self GoToSFTPWithConnection:connection password:password];
        });
    }];
    
}

- (IBAction) OnGoToSFTP:(id)sender
{
    [self showGoToSFTPSheet:nullopt];
}

- (void)GoToSavedConnection:(NetworkConnectionsManager::Connection)connection
{
    string passwd;
    bool should_save_passwd = false;
    if( !NetworkConnectionsManager::Instance().GetPassword(connection, passwd) ) {
        if( !NetworkConnectionsManager::Instance().AskForPassword(connection, passwd) )
            return;
        should_save_passwd = true;
    }
    
    auto epilog = [=](bool _success) { if(_success && should_save_passwd ) NetworkConnectionsManager::Instance().SetPassword(connection, passwd); };
    
    if( connection.IsType<NetworkConnectionsManager::FTPConnection>() )
        m_DirectoryLoadingQ->Run([=]{
            bool success = [self GoToFTPWithConnection:connection password:passwd];
            epilog(success);
        });
    else if( connection.IsType<NetworkConnectionsManager::SFTPConnection>() )
        m_DirectoryLoadingQ->Run([=]{
            bool success = [self GoToSFTPWithConnection:connection password:passwd];
            epilog(success);
        });
}

- (IBAction)OnGoToQuickListsParents:(id)sender
{
    [self popUpQuickListWithParentFolders];
}

- (IBAction)OnGoToQuickListsHistory:(id)sender
{
    [self popUpQuickListWithHistory];
}

- (IBAction)OnGoToQuickListsVolumes:(id)sender
{
    [self popUpQuickListWithVolumes];
}

- (IBAction)OnGoToQuickListsFavorites:(id)sender
{
    [self popUpQuickListWithFavorites];
}

- (IBAction)OnGoToQuickListsConnections:(id)sender
{
    [self popUpQuickListWithNetworkConnections];
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
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = NSLocalizedString(@"Are you sure want to delete this connection?", "Asking user if he really wants to delete information about a stored connection");
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
            [(PanelController*)cur RefreshDirectory];
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

// currently support volume info only on native fs
- (IBAction)OnDetailedVolumeInformation:(id)sender
{
    string path;
    if( auto i = self.view.item ) {
        if( !i.Host()->IsNativeFS() )
            return;
        if( !i.IsDotDot() )
            path = i.Path();
        else
            path = i.Directory();
    }
    else if( self.isUniform ) {
        if( !m_Data.Host()->IsNativeFS() )
            return;
        path = self.currentDirectoryPath;
    }
    else
        return;
    
    [[DetailedVolumeInformationSheetController new] showSheetForWindow:self.window withPath:path];
}

- (IBAction)performFindPanelAction:(id)sender {
    FindFilesSheetController *sheet = [FindFilesSheetController new];
    sheet.host = self.vfs;
    sheet.path = self.currentDirectoryPath;
    sheet.onPanelize = [=](const map<string, vector<string>> &_dir_to_filenames) {
        auto host = sheet.host;
        m_DirectoryLoadingQ->Run([=](const shared_ptr<SerialQueueT> &_queue){
            auto l = FetchSearchResultsAsListing(_dir_to_filenames,
                                                 host,
                                                 m_VFSFetchingFlags,
                                                 [=]{ return  _queue->IsStopped(); }
                                                 );
            if( l )
                dispatch_to_main_queue([=]{
                    [self loadNonUniformListing:l];
                });
        });
    };
    
    [sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if(auto item = sheet.selectedItem)
            [self GoToDir:item->dir_path vfs:self.vfs select_entry:item->filename async:true];
    }];
}

- (IBAction)OnFileInternalBigViewCommand:(id)sender {
    if( auto i = self.view.item ) {
        if( i.IsDir() )
            return;
        [self.mainWindowController RequestBigFileView:i.Path() with_fs:i.Host()];
    }
}

- (void)DoSelectByMask:(bool)_select {
    if(m_SelectionWithMaskPopover &&
       m_SelectionWithMaskPopover.shown)
        return;
    
    SelectionWithMaskPopupViewController *view = [[SelectionWithMaskPopupViewController alloc] init];
    [view setupForWindow:self.state.window];
    view.titleLabel.stringValue = _select ?
        NSLocalizedString(@"Select files using mask:", "Title for selection with mask popup") :
        NSLocalizedString(@"Deselect files using mask:", "Title for deselection with mask popup");
    view.handler = ^(NSString *mask) {
        [m_SelectionWithMaskPopover close];
        if( !FileMask::IsWildCard(mask) )
            mask = FileMask::ToWildCard(mask);
        
        [self SelectEntriesByMask:mask select:_select];
    };
    
    m_SelectionWithMaskPopover = [NSPopover new];
    m_SelectionWithMaskPopover.contentViewController = view;
    m_SelectionWithMaskPopover.behavior = NSPopoverBehaviorTransient;
    m_SelectionWithMaskPopover.delegate = view;
    [m_SelectionWithMaskPopover showRelativeToRect:NSMakeRect(0,
                                                              0,
                                                              self.view.bounds.size.width,
                                                              self.view.presentation->GetSingleItemHeight())
                                            ofView:self.view
                                     preferredEdge:NSMaxYEdge];
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
            [m_View setNeedsDisplay:true];
}

- (IBAction)OnQuickSelectByExtension:(id)sender
{
    [self DoQuickSelectByExtension:true];
}

- (IBAction)OnQuickDeselectByExtension:(id)sender
{
    [self DoQuickSelectByExtension:false];
}

- (IBAction)OnEjectVolume:(id)sender {
    auto &nfsm = NativeFSManager::Instance();
    if(self.vfs->IsNativeFS() && nfsm.IsVolumeContainingPathEjectable(self.currentDirectoryPath))
        nfsm.EjectVolumeContainingPath(self.currentDirectoryPath);
}

- (IBAction)OnCopyCurrentFileName:(id)sender {
    WriteSingleStringToClipboard(self.currentFocusedEntryFilename);
}

- (IBAction)OnCopyCurrentFilePath:(id)sender {
    WriteSingleStringToClipboard(self.currentFocusedEntryPath);
}

- (IBAction)OnBriefSystemOverviewCommand:(id)sender {
    if(m_BriefSystemOverview) {
        [self.state CloseOverlay:self];
        m_BriefSystemOverview = nil;
        return;
    }
    m_BriefSystemOverview = [self.state RequestBriefSystemOverview:self];
    [self UpdateBriefSystemOverview];
}

- (IBAction)OnFileViewCommand:(id)sender
{
    // Close quick preview, if it is open.
    if(m_QuickLook) {
        [self.state CloseOverlay:self];
        m_QuickLook = nil;
        return;
    }
    
    m_QuickLook = [self.state RequestQuickLookView:self];
    [self OnCursorChanged];
}

- (void)selectAll:(id)sender {
    [self SelectAllEntries:true];
}

- (void)deselectAll:(id)sender {
    [self SelectAllEntries:false];
}

- (IBAction)OnMenuInvertSelection:(id)sender {
    [self invertSelection];
}

- (IBAction)OnRefreshPanel:(id)sender {
    [self RefreshDirectory];
}

- (IBAction)OnCalculateSizes:(id)sender {
    // suboptimal - may have regular files inside (not dirs)
    [self CalculateSizes:self.selectedEntriesOrFocusedEntryWithDotDot];
}

- (IBAction)OnCalculateAllSizes:(id)sender
{
    [self CalculateSizes:DirectoriesWithoutDodDotInSortedOrder(self.data)];
}

- (IBAction)ToggleViewHiddenFiles:(id)sender{
    auto filtering = m_Data.HardFiltering();
    filtering.show_hidden = !filtering.show_hidden;
    [self ChangeHardFilteringTo:filtering];
    [self markRestorableStateAsInvalid];
}
- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender{
    PanelSortMode mode = m_Data.SortMode();
    mode.sep_dirs = !mode.sep_dirs;
    [self ChangeSortingModeTo:mode];
    [self markRestorableStateAsInvalid];
}
- (IBAction)ToggleCaseSensitiveComparison:(id)sender{
    PanelSortMode mode = m_Data.SortMode();
    mode.case_sens = !mode.case_sens;
    [self ChangeSortingModeTo:mode];
    [self markRestorableStateAsInvalid];
}
- (IBAction)ToggleNumericComparison:(id)sender{
    PanelSortMode mode = m_Data.SortMode();
    mode.numeric_sort = !mode.numeric_sort;
    [self ChangeSortingModeTo:mode];
    [self markRestorableStateAsInvalid];
}
- (IBAction)ToggleSortByName:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByName Rev:PanelSortMode::SortByNameRev];
}
- (IBAction)ToggleSortByExt:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByExt Rev:PanelSortMode::SortByExtRev];
}
- (IBAction)ToggleSortByMTime:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByMTime Rev:PanelSortMode::SortByMTimeRev];
}
- (IBAction)ToggleSortBySize:(id)sender{
    [self MakeSortWith:PanelSortMode::SortBySize Rev:PanelSortMode::SortBySizeRev];
}
- (IBAction)ToggleSortByBTime:(id)sender{
    [self MakeSortWith:PanelSortMode::SortByBTime Rev:PanelSortMode::SortByBTimeRev];
}
- (IBAction)ToggleShortViewMode:(id)sender {
    m_View.type = PanelViewType::Short;
    [self markRestorableStateAsInvalid];
}
- (IBAction)ToggleMediumViewMode:(id)sender {
    m_View.type = PanelViewType::Medium;
    [self markRestorableStateAsInvalid];
}
- (IBAction)ToggleFullViewMode:(id)sender{
    m_View.type = PanelViewType::Full;
    [self markRestorableStateAsInvalid];
}
- (IBAction)ToggleWideViewMode:(id)sender{
    m_View.type = PanelViewType::Wide;
    [self markRestorableStateAsInvalid];
}

- (IBAction)OnOpenWithExternalEditor:(id)sender {
    auto item = m_View.item;
    if( !item || item.IsDotDot() || !item.Host()->IsNativeFS() )
        return;
    
    ExternalEditorInfo *ed = [ExternalEditorsList.sharedList FindViableEditorForItem:item];
    if(ed == nil) {
        NSBeep();
        return;
    }
    
    if(ed.terminal == false) {
        if (![NSWorkspace.sharedWorkspace openFile:[NSString stringWithUTF8StdString:item.Path()]
                                   withApplication:ed.path
                                     andDeactivate:true])
            NSBeep();
    }
    else {
        MainWindowController* wnd = (MainWindowController*)self.window.delegate;
        [wnd RequestExternalEditorTerminalExecution:ed.path.fileSystemRepresentation
                                             params:[ed substituteFileName:item.Path()]
                                               file:item.Path()
         ];
    }
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
        sheet.defaultType = _delete_permanently ? FileDeletionOperationType::Delete : FileDeletionOperationType::MoveToTrash;
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
    vector<string> filenames;
    vector<uint64_t> sizes;
    
    // grab selected regular files if any
    for(int i = 0, e = (int)m_Data.SortedDirectoryEntries().size(); i < e; ++i) {
        auto item = m_Data.EntryAtSortPosition(i);
        auto item_vd = m_Data.VolatileDataAtSortPosition(i);
        if( item_vd.is_selected() && item.IsReg() && !item.IsSymlink() ) {
            filenames.emplace_back(item.Name());
            sizes.emplace_back(item.Size());
        }
    }
    
    // if have no - try focused item
    if( filenames.empty() )
        if( auto item = m_View.item )
            if( !item.IsDir() && !item.IsSymlink() ) {
                filenames.emplace_back(item.Name());
                sizes.emplace_back(item.Size());
            }

    if( filenames.empty() )
        return;
    
    CalculateChecksumSheetController *sheet = [[CalculateChecksumSheetController alloc] initWithFiles:move(filenames)
                                                                                            withSizes:move(sizes)
                                                                                               atHost:self.vfs
                                                                                               atPath:self.currentDirectoryPath];
    [sheet beginSheetForWindow:self.window
             completionHandler:^(NSModalResponse returnCode) {
                 if(sheet.didSaved) {
                     PanelControllerDelayedSelection req;
                     req.filename = sheet.savedFilename;
                     [self ScheduleDelayedSelectionChangeFor:req];
                 }
             }];
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
    [op AddOnFinishHandler:^{
        dispatch_to_main_queue([=]{
            PanelController *ss = ws;
            
            if(force_reload)
                [ss RefreshDirectory];
            
            PanelControllerDelayedSelection req;
            req.filename = name;
            req.timeout = 2s;
            req.done = [=]{
                [((PanelController*)ws).view startFieldEditorRenaming];
            };
            [ss ScheduleDelayedSelectionChangeFor:req];
        });
    }];
    
    [self.state AddOperation:op];
}

- (IBAction)OnQuickNewFolderWithSelection:(id)sender
{
    if( !self.isUniform )
        return;
    
    auto files = self.selectedEntriesOrFocusedEntry;
    if(files.empty())
        return;
    NSString *stub = NSLocalizedString(@"New Folder With Items", "Name for freshly created folder by hotkey with items");
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
    
    FileCopyOperationOptions opts;
    opts.docopy = false;
    auto op = [[FileCopyOperation alloc] initWithItems:files destinationPath:dst.native() destinationHost:self.vfs options:opts];

    bool force_reload = self.vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
    __weak PanelController *ws = self;
    [op AddOnFinishHandler:^{
        dispatch_to_main_queue([=]{
            PanelController *ss = ws;
            
            if(force_reload)
                [ss RefreshDirectory];
            
            PanelControllerDelayedSelection req;
            req.filename = name;
            req.timeout = 2s;            
            req.done = [=]{
                [((PanelController*)ws).view startFieldEditorRenaming];
            };
            [ss ScheduleDelayedSelectionChangeFor:req];
        });
    }];
    
    [self.state AddOperation:op];
}

- (IBAction)OnQuickNewFile:(id)sender
{
    path dir = self.currentDirectoryPath;
    VFSHostPtr vfs = self.vfs;
    bool force_reload = self.vfs->IsDirChangeObservingAvailable(dir.c_str()) == false;
    __weak PanelController *ws = self;
    
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
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = NSLocalizedString(@"Failed to create an empty file:", "Showing error when trying to create an empty file");
                alert.informativeText = VFSError::ToNSError(ret).localizedDescription;
                [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
                [alert runModal];
            });
        
        dispatch_to_main_queue([=]{
            PanelController *ss = ws;
            
            if(force_reload)
                [ss RefreshDirectory];
            
            PanelControllerDelayedSelection req;
            req.filename = name;
            req.timeout = 2s;
            req.done = [=]{
                [((PanelController*)ws).view startFieldEditorRenaming];
            };
            [ss ScheduleDelayedSelectionChangeFor:req];
        });
    });
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
    if( !self.view.item || !self.view.item.Host()->IsNativeFS() )
        return;
    
    try {
        auto host = make_shared<VFSXAttrHost>(self.view.item.Path(), self.view.item.Host() );
        auto context = make_shared<PanelControllerGoToDirContext>();
        context->VFS = host;
        context->RequestedDirectory = "/";
        [self GoToDirWithContext:context];
    } catch (const VFSErrorException &e) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = NSLocalizedString(@"Failed to open extended attributes", "Alert message text when failed to open xattr vfs");
        alert.informativeText = VFSError::ToNSError(e.code()).localizedDescription;
        [alert runModal];
    }
}

- (IBAction) OnRenameFileInPlace:(id)sender
{
    [self.view startFieldEditorRenaming];
}

@end
