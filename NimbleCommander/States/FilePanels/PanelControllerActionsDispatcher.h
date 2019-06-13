// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/MIMResponder.h>
#include <unordered_map>
#include "PanelViewKeystrokeSink.h"

@class PanelController;

namespace nc::panel {
namespace actions{
    struct PanelAction;
}
    
using PanelActionsMap = std::unordered_map<SEL, std::unique_ptr<const actions::PanelAction> >;
}

@interface NCPanelControllerActionsDispatcher : AttachedResponder<NCPanelViewKeystrokeSink>

- (instancetype)initWithController:(PanelController*)_controller
                     andActionsMap:(const nc::panel::PanelActionsMap&)_actions_map;

- (bool) validateActionBySelector:(SEL)_selector;


- (IBAction)OnBriefSystemOverviewCommand:(id)sender;
- (IBAction)OnRefreshPanel:(id)sender;
- (IBAction)OnFileInternalBigViewCommand:(id)sender;
- (IBAction)OnOpen:(id)sender;
- (IBAction)OnGoIntoDirectory:(id)sender;
- (IBAction)OnGoToUpperDirectory:(id)sender;
- (IBAction)OnOpenNatively:(id)sender;
- (IBAction)onOpenFileWith:(id)sender;
- (IBAction)onAlwaysOpenFileWith:(id)sender;
- (IBAction)onCompressItems:(id)sender;
- (IBAction)onCompressItemsHere:(id)sender;
- (IBAction)OnDuplicate:(id)sender;
- (IBAction)OnGoBack:(id)sender;
- (IBAction)OnGoForward:(id)sender;
- (IBAction)OnGoToFavoriteLocation:(id)sender;
- (IBAction)OnDeleteCommand:(id)sender;
- (IBAction)OnDeletePermanentlyCommand:(id)sender;
- (IBAction)OnMoveToTrash:(id)sender;
- (IBAction)OnGoToSavedConnectionItem:(id)sender;
- (IBAction)OnGoToFTP:(id)sender;
- (IBAction)OnGoToSFTP:(id)sender;
- (IBAction)onGoToWebDAV:(id)sender;
- (IBAction)OnGoToNetworkShare:(id)sender;
- (IBAction)OnGoToDropboxStorage:(id)sender;
- (IBAction)OnConnectToNetworkServer:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)OnSelectByMask:(id)sender;
- (IBAction)OnDeselectByMask:(id)sender;
- (IBAction)OnQuickSelectByExtension:(id)sender;
- (IBAction)OnQuickDeselectByExtension:(id)sender;
- (IBAction)selectAll:(id)sender;
- (IBAction)deselectAll:(id)sender;
- (IBAction)OnMenuInvertSelection:(id)sender;
- (IBAction)OnRenameFileInPlace:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)moveItemHere:(id)sender;
- (IBAction)OnGoToHome:(id)sender;
- (IBAction)OnGoToDocuments:(id)sender;
- (IBAction)OnGoToDesktop:(id)sender;
- (IBAction)OnGoToDownloads:(id)sender;
- (IBAction)OnGoToApplications:(id)sender;
- (IBAction)OnGoToUtilities:(id)sender;
- (IBAction)OnGoToLibrary:(id)sender;
- (IBAction)OnGoToRoot:(id)sender;
- (IBAction)OnGoToProcessesList:(id)sender;
- (IBAction)OnGoToFolder:(id)sender;
- (IBAction)OnCreateDirectoryCommand:(id)sender;
- (IBAction)OnCalculateChecksum:(id)sender;
- (IBAction)OnQuickNewFolder:(id)sender;
- (IBAction)OnQuickNewFolderWithSelection:(id)sender;
- (IBAction)OnQuickNewFile:(id)sender;
- (IBAction)OnBatchRename:(id)sender;
- (IBAction)OnOpenExtendedAttributes:(id)sender;
- (IBAction)OnAddToFavorites:(id)sender;
- (IBAction)OnSpotlightSearch:(id)sender;
- (IBAction)OnEjectVolume:(id)sender;
- (IBAction)OnCopyCurrentFileName:(id)sender;
- (IBAction)OnCopyCurrentFilePath:(id)sender;
- (IBAction)OnCopyCurrentFileDirectory:(id)sender;
- (IBAction)OnCalculateSizes:(id)sender;
- (IBAction)OnCalculateAllSizes:(id)sender;
- (IBAction)ToggleViewHiddenFiles:(id)sender;
- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender;
- (IBAction)ToggleExtensionlessFolders:(id)sender;
- (IBAction)ToggleCaseSensitiveComparison:(id)sender;
- (IBAction)ToggleNumericComparison:(id)sender;
- (IBAction)ToggleSortByName:(id)sender;
- (IBAction)ToggleSortByExt:(id)sender;
- (IBAction)ToggleSortByMTime:(id)sender;
- (IBAction)ToggleSortBySize:(id)sender;
- (IBAction)ToggleSortByBTime:(id)sender;
- (IBAction)ToggleSortByATime:(id)sender;
- (IBAction)onToggleViewLayout1:(id)sender;
- (IBAction)onToggleViewLayout2:(id)sender;
- (IBAction)onToggleViewLayout3:(id)sender;
- (IBAction)onToggleViewLayout4:(id)sender;
- (IBAction)onToggleViewLayout5:(id)sender;
- (IBAction)onToggleViewLayout6:(id)sender;
- (IBAction)onToggleViewLayout7:(id)sender;
- (IBAction)onToggleViewLayout8:(id)sender;
- (IBAction)onToggleViewLayout9:(id)sender;
- (IBAction)onToggleViewLayout10:(id)sender;
- (IBAction)OnOpenWithExternalEditor:(id)sender;
- (IBAction)OnFileAttributes:(id)sender;
- (IBAction)OnDetailedVolumeInformation:(id)sender;
- (IBAction)onMainMenuPerformFindAction:(id)sender;
- (IBAction)OnGoToQuickListsParents:(id)sender;
- (IBAction)OnGoToQuickListsHistory:(id)sender;
- (IBAction)OnGoToQuickListsVolumes:(id)sender;
- (IBAction)OnGoToQuickListsFavorites:(id)sender;
- (IBAction)OnGoToQuickListsConnections:(id)sender;
- (IBAction)OnCreateSymbolicLinkCommand:(id)sender;
- (IBAction)OnEditSymbolicLinkCommand:(id)sender;
- (IBAction)OnCreateHardLinkCommand:(id)sender;
- (IBAction)OnFileViewCommand:(id)sender;

@end
