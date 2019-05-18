// Copyright (C) 2018-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelControllerActions.h"
#include "PanelControllerActionsDispatcher.h"
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

// Temp dependency:
#include <NimbleCommander/Bootstrap/ActivationManager.h>

namespace nc::panel {

using namespace actions;

static std::vector<SEL> QuickListsBut(int but)
{
    std::vector<SEL> lists{
        @selector(OnGoToQuickListsParents:),
        @selector(OnGoToQuickListsHistory:),
        @selector(OnGoToQuickListsFavorites:),
        @selector(OnGoToQuickListsVolumes:),
        @selector(OnGoToQuickListsConnections:)
    };
    assert( but >= 0 && but < (int)lists.size() );
    lists.erase( lists.begin() + but );
    return lists;
}
    
PanelActionsMap BuildPanelActionsMap
    (NetworkConnectionsManager& _net_mgr,
     utility::NativeFSManager& _native_fs_mgr,
     FileOpener &_file_opener,
     NCPanelOpenWithMenuDelegate *_open_with_menu_delegate,
     std::function<NCViewerView*(NSRect)> _make_viewer,
     std::function<NCViewerViewController*()> _make_viewer_controller)
{
    PanelActionsMap m;
    auto add = [&](SEL _sel, actions::PanelAction *_action) {
        m[_sel].reset( _action );
    };

    const auto has_archive_support = bootstrap::ActivationManager::Instance().HasArchivesBrowsing();

    add(@selector(OnOpenNatively:),
        new OpenFilesWithDefaultHandler{_file_opener});
    add(@selector(onOpenFileWith:),
        new OpenFileWithSubmenu{_open_with_menu_delegate});
    add(@selector(OnOpen:),
        new Enter{has_archive_support, *m[@selector(OnOpenNatively:)]} );
    add( @selector(onAlwaysOpenFileWith:),           new AlwaysOpenFileWithSubmenu{_open_with_menu_delegate});
    add(@selector(onMainMenuPerformFindAction:),
        new FindFiles{_make_viewer,_make_viewer_controller});
    add( @selector(OnSpotlightSearch:),              new SpotlightSearch);
    add( @selector(OnDuplicate:),                    new Duplicate);
    add( @selector(OnAddToFavorites:),               new AddToFavorites);
    add( @selector(OnCalculateSizes:),               new CalculateSizes);
    add( @selector(OnCalculateAllSizes:),            new CalculateAllSizes);
    add( @selector(OnCalculateChecksum:),            new CalculateChecksum);
    add( @selector(OnQuickNewFile:),                 new MakeNewFile);
    add( @selector(OnQuickNewFolder:),               new MakeNewFolder);
    add( @selector(OnQuickNewFolderWithSelection:),  new MakeNewFolderWithSelection);
    add( @selector(copy:),                   new CopyToPasteboard);
    add( @selector(paste:),                  new PasteFromPasteboard);
    add( @selector(moveItemHere:),           new MoveFromPasteboard);
    add( @selector(selectAll:),              new SelectAll);
    add( @selector(deselectAll:),            new DeselectAll);
    add( @selector(OnMenuInvertSelection:),  new InvertSelection);
    add( @selector(ToggleSortByName:),               new ToggleSortingByName);
    add( @selector(ToggleSortByExt:),                new ToggleSortingByExtension);
    add( @selector(ToggleSortBySize:),               new ToggleSortingBySize);
    add( @selector(ToggleSortByMTime:),              new ToggleSortingByModifiedTime);
    add( @selector(ToggleSortByBTime:),              new ToggleSortingByCreatedTime);
    add( @selector(ToggleSortByATime:),              new ToggleSortingByAddedTime);
    add( @selector(ToggleCaseSensitiveComparison:),  new ToggleSortingCaseSensitivity);
    add( @selector(ToggleSeparateFoldersFromFiles:), new ToggleSortingFoldersSeparation);
    add( @selector(ToggleExtensionlessFolders:),     new ToggleSortingExtensionlessFolders);
    add( @selector(ToggleNumericComparison:),        new ToggleSortingNumerical);
    add( @selector(ToggleViewHiddenFiles:),          new ToggleSortingShowHidden);
    add( @selector(onToggleViewLayout1:),  new ToggleLayout{0});
    add( @selector(onToggleViewLayout2:),  new ToggleLayout{1});
    add( @selector(onToggleViewLayout3:),  new ToggleLayout{2});
    add( @selector(onToggleViewLayout4:),  new ToggleLayout{3});
    add( @selector(onToggleViewLayout5:),  new ToggleLayout{4});
    add( @selector(onToggleViewLayout6:),  new ToggleLayout{5});
    add( @selector(onToggleViewLayout7:),  new ToggleLayout{6});
    add( @selector(onToggleViewLayout8:),  new ToggleLayout{7});
    add( @selector(onToggleViewLayout9:),  new ToggleLayout{8});
    add( @selector(onToggleViewLayout10:), new ToggleLayout{9});
    add( @selector(OnRefreshPanel:),     new RefreshPanel);
    add( @selector(OnGoToUpperDirectory:),new GoToEnclosingFolder);
    add( @selector(OnGoIntoDirectory:),  new GoIntoFolder{has_archive_support, true});
    add( @selector(OnGoBack:),           new GoBack);
    add( @selector(OnGoForward:),        new GoForward);
    add( @selector(OnGoToHome:),         new GoToHomeFolder);
    add( @selector(OnGoToDocuments:),    new GoToDocumentsFolder);
    add( @selector(OnGoToDesktop:),      new GoToDesktopFolder);
    add( @selector(OnGoToDownloads:),    new GoToDownloadsFolder);
    add( @selector(OnGoToApplications:), new GoToApplicationsFolder);
    add( @selector(OnGoToUtilities:),    new GoToUtilitiesFolder);
    add( @selector(OnGoToLibrary:),      new GoToLibraryFolder);
    add( @selector(OnGoToRoot:),         new GoToRootFolder);
    add( @selector(OnGoToProcessesList:),new GoToProcessesList);
    add( @selector(OnGoToFolder:),       new GoToFolder);
    add( @selector(OnGoToFTP:),                  new OpenNewFTPConnection{_net_mgr});
    add( @selector(OnGoToSFTP:),                 new OpenNewSFTPConnection{_net_mgr});
    add( @selector(onGoToWebDAV:),               new OpenNewWebDAVConnection{_net_mgr});
    add( @selector(OnGoToNetworkShare:),         new OpenNewLANShare{_net_mgr});
    add( @selector(OnGoToDropboxStorage:),       new OpenNewDropboxStorage{_net_mgr});
    add( @selector(OnConnectToNetworkServer:),   new OpenNetworkConnections{_net_mgr});
    add( @selector(OnGoToSavedConnectionItem:),  new OpenExistingNetworkConnection{_net_mgr});
    add( @selector(OnGoToQuickListsParents:),   
        new ShowParentFoldersQuickList{_net_mgr, QuickListsBut(0)});
    add( @selector(OnGoToQuickListsHistory:),    
        new ShowHistoryQuickList{_net_mgr, QuickListsBut(1)});
    add( @selector(OnGoToQuickListsFavorites:),  
        new ShowFavoritesQuickList{_net_mgr, QuickListsBut(2)});
    add( @selector(OnGoToQuickListsVolumes:),    
        new ShowVolumesQuickList{_net_mgr, QuickListsBut(3)});
    add( @selector(OnGoToQuickListsConnections:),
        new ShowConnectionsQuickList{_net_mgr, QuickListsBut(4)});
    add( @selector(OnGoToFavoriteLocation:),     new GoToFavoriteLocation);
    add( @selector(OnFileViewCommand:),          new ShowQuickLook);
    add( @selector(OnBriefSystemOverviewCommand:),new ShowSystemOverview);
    add( @selector(OnFileInternalBigViewCommand:),new ViewFile);
    add( @selector(OnSelectByMask:),             new SelectAllByMask{true});
    add( @selector(OnQuickSelectByExtension:),   new SelectAllByExtension{true});
    add( @selector(OnDeselectByMask:),           new SelectAllByMask{false});
    add( @selector(OnQuickDeselectByExtension:), new SelectAllByExtension{false});
    add( @selector(OnDetailedVolumeInformation:),new ShowVolumeInformation);
    add( @selector(OnFileAttributes:),           new ChangeAttributes);
    add( @selector(OnOpenWithExternalEditor:),   new OpenWithExternalEditor{_file_opener});
    add( @selector(OnEjectVolume:),              new EjectVolume{_native_fs_mgr});
    add( @selector(OnCopyCurrentFileName:),      new CopyFileName);
    add( @selector(OnCopyCurrentFilePath:),      new CopyFilePath);
    add( @selector(OnCopyCurrentFileDirectory:), new CopyFileDirectory);
    add( @selector(OnCreateDirectoryCommand:),   new MakeNewNamedFolder);
    add( @selector(OnBatchRename:),              new BatchRename);
    add( @selector(OnRenameFileInPlace:),        new RenameInPlace);
    add( @selector(OnOpenExtendedAttributes:),   new OpenXAttr);
    add( @selector(OnMoveToTrash:),              new MoveToTrash);
    add( @selector(OnDeleteCommand:),            new Delete);
    add( @selector(OnDeletePermanentlyCommand:), new Delete{true});
    add( @selector(onCompressItemsHere:),        new CompressHere);
    add( @selector(onCompressItems:),            new CompressToOpposite);
    add( @selector(OnCreateSymbolicLinkCommand:),new CreateSymlink);
    add( @selector(OnEditSymbolicLinkCommand:),  new AlterSymlink);
    add( @selector(OnCreateHardLinkCommand:),    new CreateHardlink);
    
    return m;
}
    
}
