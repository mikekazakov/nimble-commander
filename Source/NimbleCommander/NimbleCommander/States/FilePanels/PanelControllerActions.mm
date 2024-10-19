// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelControllerActions.h"
#include "PanelControllerActionsDispatcher.h"
#include "Actions/CopyFilePaths.h"
#include "Actions/AddToFavorites.h"
#include "Actions/GoToFolder.h"
#include "Actions/EjectVolume.h"
#include "Actions/ShowVolumeInformation.h"
#include "Actions/InsertFromPasteboard.h"
#include "Actions/OpenXAttr.h"
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
#include "Actions/Delete.h"
#include "Actions/NavigateHistory.h"
#include "Actions/Duplicate.h"
#include "Actions/Compress.h"
#include "Actions/OpenFile.h"
#include "Actions/Enter.h"
#include "Actions/Link.h"
#include "Actions/ViewFile.h"
#include "Actions/RefreshPanel.h"
#include "Actions/ShowQuickLook.h"
#include "Actions/ShowSystemOverview.h"
#include "Actions/FollowSymlink.h"
#include "Actions/ShowContextMenu.h"

namespace nc::panel {

using namespace actions;

PanelActionsMap BuildPanelActionsMap(nc::config::Config &_global_config,
                                     nc::panel::NetworkConnectionsManager &_net_mgr,
                                     utility::NativeFSManager &_native_fs_mgr,
                                     nc::vfs::NativeHost &_native_host,
                                     const nc::panel::TagsStorage &_tags_storage,
                                     FileOpener &_file_opener,
                                     NCPanelOpenWithMenuDelegate *_open_with_menu_delegate,
                                     std::function<NCViewerView *(NSRect)> _make_viewer,
                                     std::function<NCViewerViewController *()> _make_viewer_controller)
{
    PanelActionsMap m;
    auto add = [&](SEL _sel, actions::PanelAction *_action) { m[_sel].reset(_action); };

    add(@selector(OnOpenNatively:), new OpenFilesWithDefaultHandler{_file_opener});
    add(@selector(onOpenFileWith:), new OpenFileWithSubmenu{_open_with_menu_delegate});
    add(@selector(OnOpen:), new Enter { *m[@selector(OnOpenNatively:)] });
    add(@selector(onAlwaysOpenFileWith:), new AlwaysOpenFileWithSubmenu{_open_with_menu_delegate});
    add(@selector(onMainMenuPerformFindAction:), new FindFiles{_make_viewer, _make_viewer_controller});
    add(@selector(OnSpotlightSearch:), new SpotlightSearch);
    add(@selector(OnDuplicate:), new Duplicate{_global_config});
    add(@selector(OnAddToFavorites:), new AddToFavorites);
    add(@selector(OnCalculateSizes:), new CalculateSizes);
    add(@selector(OnCalculateAllSizes:), new CalculateAllSizes);
    add(@selector(OnQuickNewFile:), new MakeNewFile);
    add(@selector(OnQuickNewFolder:), new MakeNewFolder);
    add(@selector(OnQuickNewFolderWithSelection:), new MakeNewFolderWithSelection);
    add(@selector(copy:), new CopyToPasteboard);
    add(@selector(paste:), new PasteFromPasteboard{_native_host});
    add(@selector(moveItemHere:), new MoveFromPasteboard{_native_host});
    add(@selector(selectAll:), new SelectAll);
    add(@selector(deselectAll:), new DeselectAll);
    add(@selector(OnMenuInvertSelection:), new InvertSelection);
    add(@selector(ToggleSortByName:), new ToggleSortingByName);
    add(@selector(ToggleSortByExt:), new ToggleSortingByExtension);
    add(@selector(ToggleSortBySize:), new ToggleSortingBySize);
    add(@selector(ToggleSortByMTime:), new ToggleSortingByModifiedTime);
    add(@selector(ToggleSortByBTime:), new ToggleSortingByCreatedTime);
    add(@selector(ToggleSortByAddTime:), new ToggleSortingByAddedTime);
    add(@selector(ToggleSortByATime:), new ToggleSortingByAccessedTime);
    add(@selector(onToggleNaturalCollation:), new ToggleSortingNaturalCollation);
    add(@selector(onToggleCaseInsensitiveCollation:), new ToggleSortingCaseInsensitiveCollation);
    add(@selector(onToggleCaseSensitiveCollation:), new ToggleSortingCaseSensitiveCollation);
    add(@selector(ToggleSeparateFoldersFromFiles:), new ToggleSortingFoldersSeparation);
    add(@selector(ToggleExtensionlessFolders:), new ToggleSortingExtensionlessFolders);
    add(@selector(ToggleViewHiddenFiles:), new ToggleSortingShowHidden);
    add(@selector(onToggleViewLayout1:), new ToggleLayout{0});
    add(@selector(onToggleViewLayout2:), new ToggleLayout{1});
    add(@selector(onToggleViewLayout3:), new ToggleLayout{2});
    add(@selector(onToggleViewLayout4:), new ToggleLayout{3});
    add(@selector(onToggleViewLayout5:), new ToggleLayout{4});
    add(@selector(onToggleViewLayout6:), new ToggleLayout{5});
    add(@selector(onToggleViewLayout7:), new ToggleLayout{6});
    add(@selector(onToggleViewLayout8:), new ToggleLayout{7});
    add(@selector(onToggleViewLayout9:), new ToggleLayout{8});
    add(@selector(onToggleViewLayout10:), new ToggleLayout{9});
    add(@selector(OnRefreshPanel:), new RefreshPanel);
    add(@selector(OnGoToUpperDirectory:), new GoToEnclosingFolder);
    add(@selector(OnGoIntoDirectory:), new GoIntoFolder{true});
    add(@selector(onFollowSymlink:), new FollowSymlink);
    add(@selector(OnGoBack:), new GoBack);
    add(@selector(OnGoForward:), new GoForward);
    add(@selector(OnGoToHome:), new GoToHomeFolder);
    add(@selector(OnGoToDocuments:), new GoToDocumentsFolder);
    add(@selector(OnGoToDesktop:), new GoToDesktopFolder);
    add(@selector(OnGoToDownloads:), new GoToDownloadsFolder);
    add(@selector(OnGoToApplications:), new GoToApplicationsFolder);
    add(@selector(OnGoToUtilities:), new GoToUtilitiesFolder);
    add(@selector(OnGoToLibrary:), new GoToLibraryFolder);
    add(@selector(OnGoToRoot:), new GoToRootFolder);
    add(@selector(OnGoToProcessesList:), new GoToProcessesList);
    add(@selector(OnGoToFolder:), new GoToFolder);
    add(@selector(OnGoToFTP:), new OpenNewFTPConnection{_net_mgr});
    add(@selector(OnGoToSFTP:), new OpenNewSFTPConnection{_net_mgr});
    add(@selector(onGoToWebDAV:), new OpenNewWebDAVConnection{_net_mgr});
    add(@selector(OnGoToNetworkShare:), new OpenNewLANShare{_net_mgr});
    add(@selector(OnGoToDropboxStorage:), new OpenNewDropboxStorage{_net_mgr});
    add(@selector(OnConnectToNetworkServer:), new OpenNetworkConnections{_net_mgr});
    add(@selector(OnGoToSavedConnectionItem:), new OpenExistingNetworkConnection{_net_mgr});
    add(@selector(OnGoToQuickListsParents:), new ShowParentFoldersQuickList{_net_mgr, _native_fs_mgr, _tags_storage});
    add(@selector(OnGoToQuickListsHistory:), new ShowHistoryQuickList{_net_mgr, _native_fs_mgr, _tags_storage});
    add(@selector(OnGoToQuickListsFavorites:), new ShowFavoritesQuickList{_net_mgr, _native_fs_mgr, _tags_storage});
    add(@selector(OnGoToQuickListsVolumes:), new ShowVolumesQuickList{_net_mgr, _native_fs_mgr, _tags_storage});
    add(@selector(OnGoToQuickListsConnections:), new ShowConnectionsQuickList{_net_mgr, _native_fs_mgr, _tags_storage});
    add(@selector(OnGoToQuickListsTags:),
        new ShowTagsQuickList{_net_mgr, _native_fs_mgr, _tags_storage, _global_config});
    add(@selector(OnGoToFavoriteLocation:), new GoToFavoriteLocation{_net_mgr});
    add(@selector(OnFileViewCommand:), new ShowQuickLook);
    add(@selector(OnBriefSystemOverviewCommand:), new ShowSystemOverview);
    add(@selector(OnFileInternalBigViewCommand:), new ViewFile);
    add(@selector(OnSelectByMask:), new SelectAllByMask{true});
    add(@selector(OnQuickSelectByExtension:), new SelectAllByExtension{true});
    add(@selector(OnDeselectByMask:), new SelectAllByMask{false});
    add(@selector(OnQuickDeselectByExtension:), new SelectAllByExtension{false});
    add(@selector(OnDetailedVolumeInformation:), new ShowVolumeInformation{_native_fs_mgr});
    add(@selector(OnFileAttributes:), new ChangeAttributes{_global_config});
    add(@selector(OnOpenWithExternalEditor:), new OpenWithExternalEditor{_file_opener});
    add(@selector(OnEjectVolume:), new EjectVolume{_native_fs_mgr});
    add(@selector(OnCopyCurrentFileName:), new CopyFileName);
    add(@selector(OnCopyCurrentFilePath:), new CopyFilePath);
    add(@selector(OnCopyCurrentFileDirectory:), new CopyFileDirectory);
    add(@selector(OnCreateDirectoryCommand:), new MakeNewNamedFolder);
    add(@selector(OnBatchRename:), new BatchRename);
    add(@selector(OnRenameFileInPlace:), new RenameInPlace);
    add(@selector(OnOpenExtendedAttributes:), new OpenXAttr);
    add(@selector(OnMoveToTrash:), new MoveToTrash{_native_fs_mgr});
    add(@selector(OnDeleteCommand:), new Delete{_native_fs_mgr});
    add(@selector(OnDeletePermanentlyCommand:), new Delete{_native_fs_mgr, true});
    add(@selector(onCompressItemsHere:), new CompressHere{_global_config});
    add(@selector(onCompressItems:), new CompressToOpposite{_global_config});
    add(@selector(OnCreateSymbolicLinkCommand:), new CreateSymlink);
    add(@selector(OnEditSymbolicLinkCommand:), new AlterSymlink);
    add(@selector(OnCreateHardLinkCommand:), new CreateHardlink);
    add(@selector(onShowContextMenu:), new ShowContextMenu);

    return m;
}

} // namespace nc::panel
