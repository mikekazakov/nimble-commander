#include <boost/algorithm/string/replace.hpp>
#include <boost/algorithm/string/split.hpp>
#include <Habanero/CommonPaths.h>
#include <Habanero/algo.h>
#include <Utility/NativeFSManager.h>
#include <VFS/VFSListingInput.h>
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
#include "ExternalEditorInfo.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include "PanelController+Menu.h"
#include "MainWindowFilePanelState.h"
#include <NimbleCommander/States/FilePanels/FindFilesSheetController.h>
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
#include "Views/SpotlightSearchPopupViewController.h"
#include "PanelAux.h"
#include "Actions/CopyFilePaths.h"
#include "Actions/AddToFavorites.h"
#include "Actions/GoToFolder.h"
#include "Actions/EjectVolume.h"
#include "Actions/ShowVolumeInformation.h"
#include "Actions/InsertFromPasteboard.h"
#include "Actions/OpenXAttr.h"
#include "Actions/CalculateChecksum.h"

static const auto g_ConfigSpotlightFormat = "filePanel.spotlight.format";
static const auto g_ConfigSpotlightMaxCount = "filePanel.spotlight.maxCount";

static shared_ptr<VFSListing> FetchSearchResultsAsListing(const map<VFSPath, vector<string>> &_dir_to_filenames, int _fetch_flags, VFSCancelChecker _cancel_checker)
{
    vector<shared_ptr<VFSListing>> listings;
    vector<vector<unsigned>> indeces;
    
    for(auto &i: _dir_to_filenames) {
        shared_ptr<VFSListing> listing;
        
        if( _cancel_checker && _cancel_checker() )
            return nullptr;
        
        auto &vfs_path = i.first;
        
        if( vfs_path.Host()->FetchFlexibleListing(vfs_path.Path().c_str(), listing, _fetch_flags, _cancel_checker) == 0) {
            listings.emplace_back(listing);
            indeces.emplace_back();
            auto &ind = indeces.back();
            
            unordered_map<string, unsigned> listing_fn_ind;
            for(unsigned listing_ind = 0, e = listing->Count(); listing_ind != e; ++listing_ind)
                listing_fn_ind[ listing->Filename(listing_ind) ] = listing_ind;
                
                for( auto &filename: i.second ) {
                    auto it = listing_fn_ind.find(filename);
                    if( it != end(listing_fn_ind) )
                        ind.emplace_back( it->second );
                }
        }
    }
    
    if( _cancel_checker && _cancel_checker() )
        return nullptr;
        
    return VFSListing::Build( VFSListing::Compose(listings, indeces) );
}

static shared_ptr<VFSListing> FetchSearchResultsAsListing(const vector<string> &_file_paths, VFSHostPtr _vfs, int _fetch_flags, VFSCancelChecker _cancel_checker)
{
    map<VFSPath, vector<string>> dir_to_filenames;
    
    for( auto &i: _file_paths ) {
        path p(i);
        auto dir = p.parent_path();
        auto filename = p.filename();
        dir_to_filenames[ VFSPath{_vfs, dir.native()} ].emplace_back( filename.native() );
    }
    
    return FetchSearchResultsAsListing(dir_to_filenames, _fetch_flags, _cancel_checker);
}

static string CookSpotlightSearchQuery( const string& _format, const string &_input )
{
    bool should_split =
        _format.find("#{query1}") != string::npos ||
        _format.find("#{query2}") != string::npos ||
        _format.find("#{query3}") != string::npos ||
        _format.find("#{query4}") != string::npos ||
        _format.find("#{query5}") != string::npos ||
        _format.find("#{query6}") != string::npos ||
        _format.find("#{query7}") != string::npos ||
        _format.find("#{query8}") != string::npos ||
        _format.find("#{query9}") != string::npos;
    
    if( !should_split )
        return boost::replace_all_copy( _format, "#{query}", _input );

    vector<string> words;
    boost::split(words,
                 _input,
                 [](char _c){ return _c == ' ';},
                 boost::token_compress_on
                 );
    
    string result = _format;
    boost::replace_all(result, "#{query}" , _input );
    boost::replace_all(result, "#{query1}", words.size() > 0 ? words[0] : "" );
    boost::replace_all(result, "#{query2}", words.size() > 1 ? words[1] : "" );
    boost::replace_all(result, "#{query3}", words.size() > 2 ? words[2] : "" );
    boost::replace_all(result, "#{query4}", words.size() > 3 ? words[3] : "" );
    boost::replace_all(result, "#{query5}", words.size() > 4 ? words[4] : "" );
    boost::replace_all(result, "#{query6}", words.size() > 5 ? words[5] : "" );
    boost::replace_all(result, "#{query7}", words.size() > 6 ? words[6] : "" );
    boost::replace_all(result, "#{query8}", words.size() > 7 ? words[7] : "" );
    boost::replace_all(result, "#{query9}", words.size() > 8 ? words[8] : "" );
    
    return result;
}

static vector<string> FetchSpotlightResults(const string& _query)
{
    string format = CookSpotlightSearchQuery( GlobalConfig().GetString(g_ConfigSpotlightFormat).value_or("kMDItemFSName == '*#{query}*'cd"),
                                              _query );
    
    MDQueryRef query = MDQueryCreate( nullptr, (CFStringRef)[NSString stringWithUTF8StdString:format], nullptr, nullptr );
    if( !query )
        return {};
    auto clear_query = at_scope_end([=]{ CFRelease(query); });
    
    MDQuerySetMaxCount( query, GlobalConfig().GetInt(g_ConfigSpotlightMaxCount) );
    
    Boolean query_result = MDQueryExecute( query, kMDQuerySynchronous );
    if( !query_result)
        return {};
    
    vector<string> result;
    for( long i = 0, e = MDQueryGetResultCount( query ); i < e; ++i ) {

        MDItemRef item = (MDItemRef)MDQueryGetResultAtIndex( query, i );
        
        CFStringRef item_path = (CFStringRef)MDItemCopyAttribute(item, kMDItemPath);
        auto clear_item_path = at_scope_end([=]{ CFRelease(item_path); });
        
        result.emplace_back( CFStringGetUTF8StdString(item_path) );
    }

    // make results unique - spotlight sometimes produces duplicates
    sort( begin(result), end(result) );
    result.erase( unique(begin(result), end(result)), result.end() );
    
    return result;
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

static const auto g_SortAscImage = [NSImage imageNamed:@"NSAscendingSortIndicator"];
static const auto g_SortDescImage = [NSImage imageNamed:@"NSDescendingSortIndicator"];
static NSImage *ImageFromSortMode( PanelData::PanelSortMode::Mode _mode )
{
    switch( _mode ) {
        case PanelDataSortMode::SortByName:         return g_SortAscImage;
        case PanelDataSortMode::SortByNameRev:      return g_SortDescImage;
        case PanelDataSortMode::SortBySize:         return g_SortDescImage;
        case PanelDataSortMode::SortBySizeRev:      return g_SortAscImage;
        case PanelDataSortMode::SortByBirthTime:    return g_SortDescImage;
        case PanelDataSortMode::SortByBirthTimeRev: return g_SortAscImage;
        case PanelDataSortMode::SortByModTime:      return g_SortDescImage;
        case PanelDataSortMode::SortByModTimeRev:   return g_SortAscImage;
        case PanelDataSortMode::SortByAddTime:      return g_SortDescImage;
        case PanelDataSortMode::SortByAddTimeRev:   return g_SortAscImage;
        default: return nil;
    }
}

- (BOOL) validateMenuItemImpl:(NSMenuItem *)item
{
    auto upd_for_sort = [](NSMenuItem * _item,
                           PanelData::PanelSortMode _mode,
                           PanelData::PanelSortMode::Mode _dir,
                           PanelData::PanelSortMode::Mode _rev ){
        if(_mode.sort == _dir || _mode.sort == _rev) {
            _item.image = ImageFromSortMode( _rev );
            _item.state = NSOnState;
        }
        else {
            _item.image = nil;
            _item.state = NSOffState;
        }
    };
    
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
    TAG(tag_sort_name,          "menu.view.sorting_by_name");
    TAG(tag_sort_ext,           "menu.view.sorting_by_extension");
    TAG(tag_sort_mod,           "menu.view.sorting_by_modify_time");
    TAG(tag_sort_size,          "menu.view.sorting_by_size");
    TAG(tag_sort_creat,         "menu.view.sorting_by_creation_time");
    TAG(tag_sort_add,           "menu.view.sorting_by_added_time");
    TAG(tag_sort_viewhidden,    "menu.view.sorting_view_hidden");
    TAG(tag_sort_sepfolders,    "menu.view.sorting_separate_folders");
    TAG(tag_sort_casesens,      "menu.view.sorting_case_sensitive");
    TAG(tag_sort_numeric,       "menu.view.sorting_numeric_comparison");
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
    IF(tag_sort_viewhidden) item.state = m_Data.HardFiltering().show_hidden;
    IF(tag_sort_sepfolders) item.state = m_Data.SortMode().sep_dirs;
    IF(tag_sort_casesens)   item.state = m_Data.SortMode().case_sens;
    IF(tag_sort_numeric)    item.state = m_Data.SortMode().numeric_sort;
    IF(tag_sort_name)       upd_for_sort(item,
                                         m_Data.SortMode(),
                                         PanelData::PanelSortMode::SortByName,
                                         PanelData::PanelSortMode::SortByNameRev );
    IF(tag_sort_ext)        upd_for_sort(item,
                                         m_Data.SortMode(),
                                         PanelData::PanelSortMode::SortByExt,
                                         PanelData::PanelSortMode::SortByExtRev );
    IF(tag_sort_mod)        upd_for_sort(item,
                                         m_Data.SortMode(),
                                         PanelData::PanelSortMode::SortByModTime,
                                         PanelData::PanelSortMode::SortByModTimeRev );
    IF(tag_sort_size)       upd_for_sort(item,
                                         m_Data.SortMode(),
                                         PanelData::PanelSortMode::SortBySize,
                                         PanelData::PanelSortMode::SortBySizeRev );
    IF(tag_sort_creat)      upd_for_sort(item,
                                         m_Data.SortMode(),
                                         PanelData::PanelSortMode::SortByBirthTime,
                                         PanelData::PanelSortMode::SortByBirthTimeRev );
    IF(tag_sort_add)        upd_for_sort(item,
                                         m_Data.SortMode(),
                                         PanelData::PanelSortMode::SortByAddTime,
                                         PanelData::PanelSortMode::SortByAddTimeRev );
#undef IF
    
    using namespace panel::actions;
    
    IF_MENU_TAG("menu.edit.paste")      return PasteFromPasteboard::ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.edit.move_here")  return MoveFromPasteboard::ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.go.back")                         return m_History.CanMoveBack() || (!self.isUniform && !m_History.Empty());
    IF_MENU_TAG("menu.go.forward")                      return m_History.CanMoveForth();
    IF_MENU_TAG("menu.go.enclosing_folder")             return self.currentDirectoryPath != "/" || (self.isUniform && self.vfs->Parent() != nullptr);
    IF_MENU_TAG("menu.go.into_folder")                  return m_View.item && !m_View.item.IsDotDot();
    IF_MENU_TAG("menu.command.file_attributes")         return m_View.item && ( (!m_View.item.IsDotDot() && m_View.item.Host()->IsNativeFS()) || m_Data.Stats().selected_entries_amount > 0 );
    IF_MENU_TAG("menu.command.volume_information") return ShowVolumeInformation::
                                                            ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.command.internal_viewer")         return m_View.item && !m_View.item.IsDir();
    IF_MENU_TAG("menu.command.external_editor")         return m_View.item && !m_View.item.IsDotDot();
    IF_MENU_TAG("menu.command.eject_volume")    return EjectVolume::ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.command.quick_look")              return m_View.item && !self.state.anyPanelCollapsed;
    IF_MENU_TAG("menu.command.system_overview")         return !self.state.anyPanelCollapsed;
    IF_MENU_TAG("menu.file.calculate_sizes")            return m_View.item;
    IF_MENU_TAG("menu.command.copy_file_name")  return CopyFileName::ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.command.copy_file_path")  return CopyFilePath::ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.file.add_to_favorites")   return AddToFavorites::ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.command.move_to_trash")           return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.delete")                  return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.delete_permanently")      return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.create_directory")        return self.isUniform && self.vfs->IsWriteable();
    IF_MENU_TAG("menu.file.calculate_checksum") return CalculateChecksum::
                                                            ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.file.new_folder")                 return self.isUniform && self.vfs->IsWriteable();
    IF_MENU_TAG("menu.file.new_folder_with_selection")  return self.isUniform && self.vfs->IsWriteable() && m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.batch_rename")            return (!self.isUniform || self.vfs->IsWriteable()) && m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
    IF_MENU_TAG("menu.command.open_xattr")      return OpenXAttr::ValidateMenuItem(self, item);
    
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

- (IBAction)onMainMenuPerformFindAction:(id)sender {
    FindFilesSheetController *sheet = [FindFilesSheetController new];
    sheet.host = self.vfs;
    sheet.path = self.currentDirectoryPath;
    sheet.onPanelize = [=](const map<VFSPath, vector<string>> &_dir_to_filenames) {
        auto host = sheet.host;
        m_DirectoryLoadingQ.Run([=]{
            auto l = FetchSearchResultsAsListing(_dir_to_filenames,
                                                 m_VFSFetchingFlags,
                                                 [=]{ return m_DirectoryLoadingQ.IsStopped(); }
                                                 );
            if( l )
                dispatch_to_main_queue([=]{
                    [self loadNonUniformListing:l];
                });
        });
    };
    
    [sheet beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if(auto item = sheet.selectedItem)
            [self GoToDir:item->dir_path vfs:item->host select_entry:item->filename async:true];
    }];
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
    
    [self showPopoverUnderPathBarWithView:view andDelegate:view];
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

- (NSPopover*)showPopoverUnderPathBarWithView:(NSViewController*)_view
                                  andDelegate:(id<NSPopoverDelegate>)_delegate
{
    const auto bounds = self.view.bounds;
    NSPopover *popover = [NSPopover new];
    popover.contentViewController = _view;
    popover.behavior = NSPopoverBehaviorTransient;
    popover.delegate = _delegate;
    [popover showRelativeToRect:NSMakeRect(0,
                                           bounds.size.height - self.view.headerBarHeight,
                                           bounds.size.width,
                                           bounds.size.height)
                         ofView:self.view
                  preferredEdge:NSMinYEdge];
    return popover;
}

- (IBAction)OnQuickDeselectByExtension:(id)sender
{
    [self DoQuickSelectByExtension:false];
}

- (IBAction)OnSpotlightSearch:(id)sender
{
    SpotlightSearchPopupViewController *view = [[SpotlightSearchPopupViewController alloc] init];
    view.handler = [=](const string& _query){
        m_DirectoryLoadingQ.Run([=]{
            if( auto l = FetchSearchResultsAsListing(FetchSpotlightResults(_query),
                                                     VFSNativeHost::SharedHost(),
                                                     m_VFSFetchingFlags,
                                                     [=]{ return m_DirectoryLoadingQ.IsStopped(); }
                                                     ) )
                dispatch_to_main_queue([=]{
                    [self loadNonUniformListing:l];
                });
        });
    };
    
    [self showPopoverUnderPathBarWithView:view andDelegate:view];
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
    auto filtering = m_Data.HardFiltering();
    filtering.show_hidden = !filtering.show_hidden;
    [self ChangeHardFilteringTo:filtering];
    [self markRestorableStateAsInvalid];
    [m_View dataUpdated];
}

- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender
{
    auto mode = m_Data.SortMode();
    mode.sep_dirs = !mode.sep_dirs;
    [self changeSortingModeTo:mode];
}

- (IBAction)ToggleCaseSensitiveComparison:(id)sender
{
    auto mode = m_Data.SortMode();
    mode.case_sens = !mode.case_sens;
    [self changeSortingModeTo:mode];
}

- (IBAction)ToggleNumericComparison:(id)sender
{
    auto mode = m_Data.SortMode();
    mode.numeric_sort = !mode.numeric_sort;
    [self changeSortingModeTo:mode];
}

- (IBAction)ToggleSortByName:(id)sender
{
    [self MakeSortWith:PanelData::PanelSortMode::SortByName Rev:PanelData::PanelSortMode::SortByNameRev];
}

- (IBAction)ToggleSortByExt:(id)sender
{
    [self MakeSortWith:PanelData::PanelSortMode::SortByExt Rev:PanelData::PanelSortMode::SortByExtRev];
}

- (IBAction)ToggleSortByMTime:(id)sender
{
    [self MakeSortWith:PanelData::PanelSortMode::SortByModTime Rev:PanelData::PanelSortMode::SortByModTimeRev];
}

- (IBAction)ToggleSortBySize:(id)sender
{
    [self MakeSortWith:PanelData::PanelSortMode::SortBySize Rev:PanelData::PanelSortMode::SortBySizeRev];
}

- (IBAction)ToggleSortByBTime:(id)sender
{
    [self MakeSortWith:PanelData::PanelSortMode::SortByBirthTime Rev:PanelData::PanelSortMode::SortByBirthTimeRev];
}

- (IBAction)ToggleSortByATime:(id)sender
{
    [self MakeSortWith:PanelData::PanelSortMode::SortByAddTime Rev:PanelData::PanelSortMode::SortByAddTimeRev];
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
    auto item = m_View.item;
    if( !item || item.IsDotDot() )
        return;
    
    auto ed = AppDelegate.me.externalEditorsStorage.ViableEditorForItem(item);
    if( !ed ) {
        NSBeep();
        return;
    }
    
    if( ed->OpenInTerminal() == false )
        PanelVFSFileWorkspaceOpener::Open(item.Path(),
                                          item.Host(),
                                          ed->Path(),
                                          self);
    else
        PanelVFSFileWorkspaceOpener::OpenInExternalEditorTerminal(item.Path(),
                                                                  item.Host(),
                                                                  ed,
                                                                  item.Filename(),
                                                                  self);
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
