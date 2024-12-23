// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "PanelControllerActionsDispatcher.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/Alert.h>
#include <Utility/NSMenu+Hierarchical.h>
#include "PanelController.h"
#include "Helpers/Pasteboard.h"
#include "Actions/GoToFolder.h"
#include "Actions/OpenFile.h"
#include "Actions/Enter.h"
#include <iostream>

using namespace nc::core;
using namespace nc::panel;
namespace nc::panel {

static const actions::PanelAction *ActionBySel(SEL _sel, const PanelActionsMap &_map) noexcept;
static void Perform(SEL _sel, const PanelActionsMap &_map, PanelController *_target, id _sender);

} // namespace nc::panel

@implementation NCPanelControllerActionsDispatcher {
    __unsafe_unretained PanelController *m_PC;
    const nc::panel::PanelActionsMap *m_AM;
}

- (instancetype)initWithController:(PanelController *)_controller
                     andActionsMap:(const nc::panel::PanelActionsMap &)_actions_map
{
    self = [super init];
    if( self ) {
        m_PC = _controller;
        m_AM = &_actions_map;
    }
    return self;
}

- (int)bidForHandlingKeyDown:(NSEvent *)_event forPanelView:(PanelView *)_panel_view
{
    return [self bidForHandlingKeyDown:_event forPanelView:_panel_view andHandle:false];
}

- (void)handleKeyDown:(NSEvent *)_event forPanelView:(PanelView *)_panel_view
{
    [self bidForHandlingKeyDown:_event forPanelView:_panel_view andHandle:true];
}

- (int)bidForHandlingKeyDown:(NSEvent *)_event
                forPanelView:(PanelView *) [[maybe_unused]] _panel_view
                   andHandle:(bool)_handle
{
    const auto event_hotkey = nc::utility::ActionShortcut(nc::utility::ActionShortcut::EventData(_event));

    static ActionsShortcutsManager::ShortCut hk_file_open;         //
    static ActionsShortcutsManager::ShortCut hk_file_open_native;  //
    static ActionsShortcutsManager::ShortCut hk_go_root;           //
    static ActionsShortcutsManager::ShortCut hk_go_home;           //
    static ActionsShortcutsManager::ShortCut hk_preview;           //
    static ActionsShortcutsManager::ShortCut hk_go_into;           //
    static ActionsShortcutsManager::ShortCut hk_go_outside;        //
    static ActionsShortcutsManager::ShortCut hk_show_context_menu; //
    [[clang::no_destroy]] static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater(
        std::initializer_list<ActionsShortcutsManager::ShortCutsUpdater::UpdateTarget>{
            {.shortcut = &hk_file_open, .action = "menu.file.enter"},
            {.shortcut = &hk_file_open_native, .action = "menu.file.open"},
            {.shortcut = &hk_go_root, .action = "panel.go_root"},
            {.shortcut = &hk_go_home, .action = "panel.go_home"},
            {.shortcut = &hk_preview, .action = "panel.show_preview"},
            {.shortcut = &hk_go_into, .action = "panel.go_into_folder"},
            {.shortcut = &hk_go_outside, .action = "panel.go_into_enclosing_folder"},
            {.shortcut = &hk_show_context_menu, .action = "panel.show_context_menu"}});

    if( hk_preview == event_hotkey ) {
        if( _handle ) {
            [self OnFileViewCommand:self];
            return view::BiddingPriority::High;
        }
        else
            return [self validateActionBySelector:@selector(OnFileViewCommand:)] ? view::BiddingPriority::High
                                                                                 : view::BiddingPriority::Skip;
    }

    if( hk_go_home == event_hotkey ) {
        if( _handle ) {
            static int tag = ActionsShortcutsManager::TagFromAction("menu.go.home").value_or(-1);
            [[NSApp menu] performActionForItemWithTagHierarchical:tag];
        }
        return view::BiddingPriority::High;
    }

    if( hk_go_root == event_hotkey ) {
        if( _handle ) {
            static int tag = ActionsShortcutsManager::TagFromAction("menu.go.root").value_or(-1);
            [[NSApp menu] performActionForItemWithTagHierarchical:tag];
        }
        return view::BiddingPriority::High;
    }

    if( hk_go_into == event_hotkey ) {
        if( _handle ) {
            static int tag = ActionsShortcutsManager::TagFromAction("menu.go.into_folder").value_or(-1);
            [[NSApp menu] performActionForItemWithTagHierarchical:tag];
        }
        return view::BiddingPriority::High;
    }

    if( hk_go_outside == event_hotkey ) {
        if( _handle ) {
            static int tag = ActionsShortcutsManager::TagFromAction("menu.go.enclosing_folder").value_or(-1);
            [[NSApp menu] performActionForItemWithTagHierarchical:tag];
        }
        return view::BiddingPriority::High;
    }

    if( hk_file_open == event_hotkey ) {
        if( _handle ) {
            // we keep it here to avoid blinking on menu item
            [self OnOpen:nil];
        }
        return view::BiddingPriority::High;
    }

    if( hk_file_open_native == event_hotkey ) {
        if( _handle ) {
            [self executeBySelectorIfValidOrBeep:@selector(OnOpenNatively:) withSender:self];
        }
        return view::BiddingPriority::High;
    }

    if( hk_show_context_menu == event_hotkey ) {
        if( _handle ) {
            [self executeBySelectorIfValidOrBeep:@selector(onShowContextMenu:) withSender:self];
        }
        return view::BiddingPriority::High;
    }

    return view::BiddingPriority::Skip;
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    try {
        if( const auto action = ActionBySel(item.action, *m_AM) )
            return action->ValidateMenuItem(m_PC, item);
        return true;
    } catch( const std::exception &e ) {
        std::cerr << "validateMenuItem has caught an exception: " << e.what() << '\n';
    } catch( ... ) {
        std::cerr << "validateMenuItem has caught an unknown exception!" << '\n';
    }
    return false;
}

- (bool)validateActionBySelector:(SEL)_selector
{
    if( const auto action = ActionBySel(_selector, *m_AM) ) {
        try {
            return action->Predicate(m_PC);
        } catch( const std::exception &e ) {
            std::cerr << "validateActionBySelector has caught an exception: " << e.what() << '\n';
        } catch( ... ) {
            std::cerr << "validateActionBySelector has caught an unknown exception!" << '\n';
        }
        return false;
    }
    return false;
}

- (void)executeBySelectorIfValidOrBeep:(SEL)_selector withSender:(id)_sender
{
    const auto is_valid = [self validateActionBySelector:_selector];
    if( is_valid )
        Perform(_selector, *m_AM, m_PC, _sender);
    else
        NSBeep();
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
{
    if( ([sendType isEqualToString:NSFilenamesPboardType] ||
         [sendType isEqualToString:(__bridge NSString *)kUTTypeFileURL]) )
        return self;

    return [super validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
    if( [types containsObject:(__bridge NSString *)kUTTypeFileURL] )
        return PasteboardSupport::WriteURLSPBoard(m_PC.selectedEntriesOrFocusedEntry, pboard);
    if( [types containsObject:NSFilenamesPboardType] )
        return PasteboardSupport::WriteFilesnamesPBoard(m_PC.selectedEntriesOrFocusedEntry, pboard);
    return false;
}
#pragma clang diagnostic pop

#define PERFORM Perform(_cmd, *m_AM, m_PC, sender)

- (IBAction)OnBriefSystemOverviewCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnRefreshPanel:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileInternalBigViewCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnOpen:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoIntoDirectory:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToUpperDirectory:(id)sender
{
    PERFORM;
}
- (IBAction)OnOpenNatively:(id)sender
{
    PERFORM;
}
- (IBAction)onOpenFileWith:(id)sender
{
    PERFORM;
}
- (IBAction)onAlwaysOpenFileWith:(id)sender
{
    PERFORM;
}
- (IBAction)onCompressItems:(id)sender
{
    PERFORM;
}
- (IBAction)onCompressItemsHere:(id)sender
{
    PERFORM;
}
- (IBAction)OnDuplicate:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoBack:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoForward:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToFavoriteLocation:(id)sender
{
    PERFORM;
}
- (IBAction)OnDeleteCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnDeletePermanentlyCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnMoveToTrash:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToSavedConnectionItem:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToFTP:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToSFTP:(id)sender
{
    PERFORM;
}
- (IBAction)onGoToWebDAV:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToNetworkShare:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToDropboxStorage:(id)sender
{
    PERFORM;
}
- (IBAction)OnConnectToNetworkServer:(id)sender
{
    PERFORM;
}
- (IBAction)copy:(id)sender
{
    PERFORM;
}
- (IBAction)OnSelectByMask:(id)sender
{
    PERFORM;
}
- (IBAction)OnDeselectByMask:(id)sender
{
    PERFORM;
}
- (IBAction)OnQuickSelectByExtension:(id)sender
{
    PERFORM;
}
- (IBAction)OnQuickDeselectByExtension:(id)sender
{
    PERFORM;
}
- (IBAction)selectAll:(id)sender
{
    PERFORM;
}
- (IBAction)deselectAll:(id)sender
{
    PERFORM;
}
- (IBAction)OnMenuInvertSelection:(id)sender
{
    PERFORM;
}
- (IBAction)OnRenameFileInPlace:(id)sender
{
    PERFORM;
}
- (IBAction)paste:(id)sender
{
    PERFORM;
}
- (IBAction)moveItemHere:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToHome:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToDocuments:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToDesktop:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToDownloads:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToApplications:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToUtilities:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToLibrary:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToRoot:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToProcessesList:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToFolder:(id)sender
{
    PERFORM;
}
- (IBAction)OnCreateDirectoryCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnQuickNewFolder:(id)sender
{
    PERFORM;
}
- (IBAction)OnQuickNewFolderWithSelection:(id)sender
{
    PERFORM;
}
- (IBAction)OnQuickNewFile:(id)sender
{
    PERFORM;
}
- (IBAction)OnBatchRename:(id)sender
{
    PERFORM;
}
- (IBAction)OnOpenExtendedAttributes:(id)sender
{
    PERFORM;
}
- (IBAction)OnAddToFavorites:(id)sender
{
    PERFORM;
}
- (IBAction)OnSpotlightSearch:(id)sender
{
    PERFORM;
}
- (IBAction)OnEjectVolume:(id)sender
{
    PERFORM;
}
- (IBAction)OnCopyCurrentFileName:(id)sender
{
    PERFORM;
}
- (IBAction)OnCopyCurrentFilePath:(id)sender
{
    PERFORM;
}
- (IBAction)OnCopyCurrentFileDirectory:(id)sender
{
    PERFORM;
}
- (IBAction)OnCalculateSizes:(id)sender
{
    PERFORM;
}
- (IBAction)OnCalculateAllSizes:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleViewHiddenFiles:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleSeparateFoldersFromFiles:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleExtensionlessFolders:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleNaturalCollation:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleCaseInsensitiveCollation:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleCaseSensitiveCollation:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleSortByName:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleSortByExt:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleSortByMTime:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleSortBySize:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleSortByBTime:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleSortByAddTime:(id)sender
{
    PERFORM;
}
- (IBAction)ToggleSortByATime:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout1:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout2:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout3:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout4:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout5:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout6:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout7:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout8:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout9:(id)sender
{
    PERFORM;
}
- (IBAction)onToggleViewLayout10:(id)sender
{
    PERFORM;
}
- (IBAction)OnOpenWithExternalEditor:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileAttributes:(id)sender
{
    PERFORM;
}
- (IBAction)OnDetailedVolumeInformation:(id)sender
{
    PERFORM;
}
- (IBAction)onMainMenuPerformFindAction:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToQuickListsParents:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToQuickListsHistory:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToQuickListsVolumes:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToQuickListsFavorites:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToQuickListsConnections:(id)sender
{
    PERFORM;
}
- (IBAction)OnGoToQuickListsTags:(id)sender
{
    PERFORM;
}
- (IBAction)OnCreateSymbolicLinkCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnEditSymbolicLinkCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnCreateHardLinkCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileViewCommand:(id)sender
{
    PERFORM;
}
- (IBAction)onFollowSymlink:(id)sender
{
    PERFORM;
}
- (IBAction)onShowContextMenu:(id)sender
{
    PERFORM;
}
#undef PERFORM

@end

using namespace nc::panel::actions;
namespace nc::panel {

static const actions::PanelAction *ActionBySel(SEL _sel, const PanelActionsMap &_map) noexcept
{
    const auto action = _map.find(_sel);
    return action == end(_map) ? nullptr : action->second.get();
}

static void Perform(SEL _sel, const PanelActionsMap &_map, PanelController *_target, id _sender)
{
    if( const auto action = ActionBySel(_sel, _map) ) {
        try {
            action->Perform(_target, _sender);
        } catch( std::exception &e ) {
            ShowExceptionAlert(e);
        } catch( ... ) {
            ShowExceptionAlert();
        }
    }
    else {
        std::cerr << "warning - unrecognized selector: " << NSStringFromSelector(_sel).UTF8String << '\n';
    }
}

} // namespace nc::panel
