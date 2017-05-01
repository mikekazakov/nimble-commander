#include <Habanero/algo.h>
#include <Utility/NativeFSManager.h>
#include <VFS/Native.h>
#include <NimbleCommander/Core/Alert.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include "PanelController+Menu.h"
#include "MainWindowFilePanelState.h"
#include <NimbleCommander/States/FilePanels/PanelDataPersistency.h>
#include <NimbleCommander/States/FilePanels/FavoritesMenuDelegate.h>
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/Operations/Delete/FileDeletionSheetController.h>
#include <NimbleCommander/Bootstrap/AppDelegate.h>
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
#include "Actions/MakeNew.h"
#include "Actions/CalculateSizes.h"
#include "Actions/BatchRename.h"
#include "Actions/ToggleLayout.h"
#include "Actions/ChangeAttributes.h"
#include "Actions/RenameInPlace.h"
#include "Actions/Select.h"
#include "Actions/CopyToPasteboard.h"
#include "Actions/OpenNetworkConnection.h"

static const panel::actions::PanelAction *ActionByTag(int _tag) noexcept;
static void Perform(SEL _sel, PanelController *_target, id _sender);

@implementation PanelController (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    try {
        const auto tag = (int)item.tag;
        if( auto a = ActionByTag(tag) )
            return a->ValidateMenuItem(self, item);
        IF_MENU_TAG("menu.go.back")                         return m_History.CanMoveBack() || (!self.isUniform && !m_History.Empty());
        IF_MENU_TAG("menu.go.forward")                      return m_History.CanMoveForth();
        IF_MENU_TAG("menu.go.enclosing_folder")             return self.currentDirectoryPath != "/" || (self.isUniform && self.vfs->Parent() != nullptr);
        IF_MENU_TAG("menu.go.into_folder")                  return m_View.item && !m_View.item.IsDotDot();
        IF_MENU_TAG("menu.command.internal_viewer")         return m_View.item && !m_View.item.IsDir();
        IF_MENU_TAG("menu.command.quick_look")              return m_View.item && !self.state.anyPanelCollapsed;
        IF_MENU_TAG("menu.command.system_overview")         return !self.state.anyPanelCollapsed;
        IF_MENU_TAG("menu.command.move_to_trash")           return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
        IF_MENU_TAG("menu.command.delete")                  return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
        IF_MENU_TAG("menu.command.delete_permanently")      return m_View.item && (!m_View.item.IsDotDot() || m_Data.Stats().selected_entries_amount > 0);
        return true;
    }
    catch(exception &e) {
        cout << "validateMenuItem has caught an exception: " << e.what() << endl;
    }
    catch(...) {
        cout << "validateMenuItem has caught an unknown exception!" << endl;
    }
    return false;
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

- (IBAction)OnGoToFavoriteLocation:(id)sender
{
    if( auto menuitem = objc_cast<NSMenuItem>(sender) )
        if( auto holder = objc_cast<AnyHolder>(menuitem.representedObject) )
            if( auto location = any_cast<PanelDataPersisency::Location>(&holder.any) )
                [self goToPersistentLocation:*location];
}

- (IBAction) OnGoToSavedConnectionItem:(id)sender
{
    Perform(_cmd, self, sender);
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

- (IBAction)OnFileInternalBigViewCommand:(id)sender {
    if( auto i = self.view.item ) {
        if( i.IsDir() )
            return;
        [self.mainWindowController RequestBigFileView:i.Path() with_fs:i.Host()];
    }
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

- (IBAction)OnRefreshPanel:(id)sender
{
    [self forceRefreshPanel];
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

- (IBAction)OnGoToFTP:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToSFTP:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToNetworkShare:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnConnectToNetworkServer:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)copy:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnSelectByMask:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnDeselectByMask:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickSelectByExtension:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickDeselectByExtension:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)selectAll:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)deselectAll:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnMenuInvertSelection:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnRenameFileInPlace:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)paste:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)moveItemHere:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToHome:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToDocuments:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToDesktop:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToDownloads:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToApplications:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToUtilities:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToLibrary:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToRoot:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToProcessesList:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToFolder:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCreateDirectoryCommand:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCalculateChecksum:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickNewFolder:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickNewFolderWithSelection:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnQuickNewFile:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnBatchRename:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnOpenExtendedAttributes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnAddToFavorites:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnSpotlightSearch:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnEjectVolume:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCopyCurrentFileName:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCopyCurrentFilePath:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCalculateSizes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnCalculateAllSizes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleViewHiddenFiles:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleExtensionlessFolders:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleCaseSensitiveComparison:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleNumericComparison:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByName:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByExt:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByMTime:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortBySize:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByBTime:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)ToggleSortByATime:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout1:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout2:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout3:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout4:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout5:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout6:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout7:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout8:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout9:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onToggleViewLayout10:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnOpenWithExternalEditor:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnFileAttributes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnDetailedVolumeInformation:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onMainMenuPerformFindAction:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsParents:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsHistory:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsVolumes:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsFavorites:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnGoToQuickListsConnections:(id)sender { Perform(_cmd, self, sender); }
@end

using namespace panel::actions;
static const tuple<const char*, SEL, const PanelAction *> g_Wiring[] = {
{"menu.file.find",                      @selector(onMainMenuPerformFindAction:),    new FindFiles},
{"menu.file.find_with_spotlight",       @selector(OnSpotlightSearch:),              new SpotlightSearch},
{"menu.file.add_to_favorites",          @selector(OnAddToFavorites:),               new AddToFavorites},
{"menu.file.calculate_sizes",           @selector(OnCalculateSizes:),               new CalculateSizes},
{"menu.file.calculate_all_sizes",       @selector(OnCalculateAllSizes:),            new CalculateAllSizes},
{"menu.file.calculate_checksum",        @selector(OnCalculateChecksum:),            new CalculateChecksum},
{"menu.file.new_file",                  @selector(OnQuickNewFile:),                 new MakeNewFile},
{"menu.file.new_folder",                @selector(OnQuickNewFolder:),               new MakeNewFolder},
{"menu.file.new_folder_with_selection", @selector(OnQuickNewFolderWithSelection:),  new MakeNewFolderWithSelection},
{"menu.edit.copy",                      @selector(copy:),                   new CopyToPasteboard},
{"menu.edit.paste",                     @selector(paste:),                  new PasteFromPasteboard},
{"menu.edit.move_here",                 @selector(moveItemHere:),           new MoveFromPasteboard},
{"menu.edit.select_all",                @selector(selectAll:),              new SelectAll},
{"menu.edit.deselect_all",              @selector(deselectAll:),            new DeselectAll},
{"menu.edit.invert_selection",          @selector(OnMenuInvertSelection:),  new InvertSelection},
{"menu.view.sorting_by_name",               @selector(ToggleSortByName:),               new ToggleSortingByName},
{"menu.view.sorting_by_extension",          @selector(ToggleSortByExt:),                new ToggleSortingByExtension},
{"menu.view.sorting_by_size",               @selector(ToggleSortBySize:),               new ToggleSortingBySize},
{"menu.view.sorting_by_modify_time",        @selector(ToggleSortByMTime:),              new ToggleSortingByModifiedTime},
{"menu.view.sorting_by_creation_time",      @selector(ToggleSortByBTime:),              new ToggleSortingByCreatedTime},
{"menu.view.sorting_by_added_time",         @selector(ToggleSortByATime:),              new ToggleSortingByAddedTime},
{"menu.view.sorting_case_sensitive",        @selector(ToggleCaseSensitiveComparison:),  new ToggleSortingCaseSensitivity},
{"menu.view.sorting_separate_folders",      @selector(ToggleSeparateFoldersFromFiles:), new ToggleSortingFoldersSeparation},
{"menu.view.sorting_extensionless_folders", @selector(ToggleExtensionlessFolders:),     new ToggleSortingExtensionlessFolders},
{"menu.view.sorting_numeric_comparison",    @selector(ToggleNumericComparison:),        new ToggleSortingNumerical},
{"menu.view.sorting_view_hidden",           @selector(ToggleViewHiddenFiles:),          new ToggleSortingShowHidden},
{"menu.view.toggle_layout_1",  @selector(onToggleViewLayout1:),  new ToggleLayout{0}},
{"menu.view.toggle_layout_2",  @selector(onToggleViewLayout2:),  new ToggleLayout{1}},
{"menu.view.toggle_layout_3",  @selector(onToggleViewLayout3:),  new ToggleLayout{2}},
{"menu.view.toggle_layout_4",  @selector(onToggleViewLayout4:),  new ToggleLayout{3}},
{"menu.view.toggle_layout_5",  @selector(onToggleViewLayout5:),  new ToggleLayout{4}},
{"menu.view.toggle_layout_6",  @selector(onToggleViewLayout6:),  new ToggleLayout{5}},
{"menu.view.toggle_layout_7",  @selector(onToggleViewLayout7:),  new ToggleLayout{6}},
{"menu.view.toggle_layout_8",  @selector(onToggleViewLayout8:),  new ToggleLayout{7}},
{"menu.view.toggle_layout_9",  @selector(onToggleViewLayout9:),  new ToggleLayout{8}},
{"menu.view.toggle_layout_10", @selector(onToggleViewLayout10:), new ToggleLayout{9}},
{"menu.go.home",            @selector(OnGoToHome:),         new GoToHomeFolder},
{"menu.go.documents",       @selector(OnGoToDocuments:),    new GoToDocumentsFolder},
{"menu.go.desktop",         @selector(OnGoToDesktop:),      new GoToDesktopFolder},
{"menu.go.downloads",       @selector(OnGoToDownloads:),    new GoToDownloadsFolder},
{"menu.go.applications",    @selector(OnGoToApplications:), new GoToApplicationsFolder},
{"menu.go.utilities",       @selector(OnGoToUtilities:),    new GoToUtilitiesFolder},
{"menu.go.library",         @selector(OnGoToLibrary:),      new GoToLibraryFolder},
{"menu.go.root",            @selector(OnGoToRoot:),         new GoToRootFolder},
{"menu.go.processes_list",  @selector(OnGoToProcessesList:),new GoToProcessesList},
{"menu.go.to_folder",       @selector(OnGoToFolder:),       new GoToFolder},
{"menu.go.connect.ftp",             @selector(OnGoToFTP:),                  new OpenNewFTPConnection},
{"menu.go.connect.sftp",            @selector(OnGoToSFTP:),                 new OpenNewSFTPConnection},
{"menu.go.connect.lanshare",        @selector(OnGoToNetworkShare:),         new OpenNewLANShare},
{"menu.go.connect.network_server",  @selector(OnConnectToNetworkServer:),   new OpenNetworkConnections},
{"",                                @selector(OnGoToSavedConnectionItem:),  new OpenExistingNetworkConnection},
{"menu.go.quick_lists.parent_folders",  @selector(OnGoToQuickListsParents:),    new ShowParentFoldersQuickList},
{"menu.go.quick_lists.history",         @selector(OnGoToQuickListsHistory:),    new ShowHistoryQuickList},
{"menu.go.quick_lists.favorites",       @selector(OnGoToQuickListsFavorites:),  new ShowFavoritesQuickList},
{"menu.go.quick_lists.volumes",         @selector(OnGoToQuickListsVolumes:),    new ShowVolumesQuickList},
{"menu.go.quick_lists.connections",     @selector(OnGoToQuickListsConnections:),new ShowConnectionsQuickList},
{"menu.command.select_with_mask",       @selector(OnSelectByMask:),             new SelectAllByMask{true}},
{"menu.command.select_with_extension",  @selector(OnQuickSelectByExtension:),   new SelectAllByExtension{true}},
{"menu.command.deselect_with_mask",     @selector(OnDeselectByMask:),           new SelectAllByMask{false}},
{"menu.command.deselect_with_extension",@selector(OnQuickDeselectByExtension:), new SelectAllByExtension{false}},
{"menu.command.volume_information",     @selector(OnDetailedVolumeInformation:),new ShowVolumeInformation},
{"menu.command.file_attributes",        @selector(OnFileAttributes:),           new ChangeAttributes},
{"menu.command.external_editor",        @selector(OnOpenWithExternalEditor:),   new OpenWithExternalEditor},
{"menu.command.eject_volume",           @selector(OnEjectVolume:),              new EjectVolume},
{"menu.command.copy_file_name",         @selector(OnCopyCurrentFileName:),      new CopyFileName},
{"menu.command.copy_file_path",         @selector(OnCopyCurrentFilePath:),      new CopyFilePath},
{"menu.command.create_directory",       @selector(OnCreateDirectoryCommand:),   new MakeNewNamedFolder},
{"menu.command.batch_rename",           @selector(OnBatchRename:),              new BatchRename},
{"menu.command.rename_in_place",        @selector(OnRenameFileInPlace:),        new RenameInPlace},
{"menu.command.open_xattr",             @selector(OnOpenExtendedAttributes:),   new OpenXAttr},
};

static const PanelAction *ActionByTag(int _tag) noexcept
{
    static const auto actions = []{
        unordered_map<int, const PanelAction*> m;
        auto &am = ActionsShortcutsManager::Instance();
        for( auto &a: g_Wiring )
            if( get<0>(a)[0] != 0 ) {
                if( auto tag = am.TagFromAction(get<0>(a)); tag >= 0 )
                    m.emplace( tag, get<2>(a) );
                else
                    cout << "warning - unrecognized action: " << get<0>(a) << endl;
            }
        return m;
    }();
    const auto v = actions.find(_tag);
    return v == end(actions) ? nullptr : v->second;
}

static void Perform(SEL _sel, PanelController *_target, id _sender)
{
    static const auto actions = []{
        unordered_map<SEL, const PanelAction*> m;
        for( auto &a: g_Wiring )
            m.emplace( get<1>(a), get<2>(a) );
        return m;
    }();
    if( const auto v = actions.find(_sel); v != end(actions) )
        v->second->Perform(_target, _sender);
    else
        cout << "warning - unrecognized selector: " <<
            NSStringFromSelector(_sel).UTF8String << endl;
}
