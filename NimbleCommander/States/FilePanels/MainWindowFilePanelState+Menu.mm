#include <Habanero/CommonPaths.h>
#include <Utility/NSMenu+Hierarchical.h>
#include <NimbleCommander/Operations/Link/FileLinkNewSymlinkSheetController.h>
#include <NimbleCommander/Operations/Link/FileLinkAlterSymlinkSheetController.h>
#include <NimbleCommander/Operations/Link/FileLinkNewHardlinkSheetController.h>
#include <NimbleCommander/Operations/Link/FileLinkOperation.h>
#include <NimbleCommander/Operations/Copy/FileCopyOperation.h>
#include <NimbleCommander/Operations/Copy/MassCopySheetController.h>
#include <NimbleCommander/Operations/Delete/FileDeletionOperation.h>
#include <NimbleCommander/Operations/Compress/FileCompressOperation.h>
#include <NimbleCommander/Operations/OperationsController.h>
#include "MainWindowFilePanelState+Menu.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/States/FilePanels/PanelController.h>
#include "PanelAux.h"
#include "Views/FilePanelMainSplitView.h"
#include <NimbleCommander/States/MainWindowController.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/States/FilePanels/ToolsMenuDelegate.h>
#include <NimbleCommander/States/FilePanels/MainWindowFilePanelsStateToolbarDelegate.h>
#include "Actions/TabSelection.h"
#include "PanelData.h"
#include "PanelView.h"

static const auto g_ConfigGeneralShowTabs = "general.showTabs";

@implementation MainWindowFilePanelState (Menu)

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
    const auto tag = item.tag;

    IF_MENU_TAG("menu.view.swap_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.view.sync_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.file.open_in_opposite_panel")  return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item;
    IF_MENU_TAG("menu.command.compress_here")        return self.isPanelActive && self.activePanelView.item && !self.activePanelView.item.IsDotDot() && self.activePanelController.isUniform;
    IF_MENU_TAG("menu.command.compress_to_opposite") return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && !self.activePanelView.item.IsDotDot() && self.oppositePanelController.isUniform;
    IF_MENU_TAG("menu.command.link_create_soft")     return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed &&
        self.activePanelView.item && self.activePanelView.item.Host()->IsNativeFS() && self.oppositePanelController.isUniform && self.oppositePanelController.vfs->IsNativeFS();
    IF_MENU_TAG("menu.command.link_create_hard")     return self.isPanelActive && self.activePanelView.item && !self.activePanelView.item.IsDir() && self.activePanelView.item.Host()->IsNativeFS();
    IF_MENU_TAG("menu.command.link_edit")            return self.isPanelActive && self.activePanelView.item && self.activePanelView.item.IsSymlink() && self.activePanelView.item.Host()->IsNativeFS();
    IF_MENU_TAG("menu.command.copy_to")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.copy_as")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.move_to")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.move_as")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.rename_in_place")      return self.isPanelActive && self.activePanelView.item && !self.activePanelView.item.IsDotDot() && self.activePanelView.item.Host()->IsWritable();
    IF_MENU_TAG("menu.file.close") {
        unsigned tabs = self.currentSideTabsCount;
        if( tabs == 0 ) {
            // in this case (no other adequate responders) - pass validation  up
            NSResponder *resp = self;
            while( (resp = resp.nextResponder) )
                if( [resp respondsToSelector:item.action] && [resp respondsToSelector:@selector(validateMenuItem:)] )
                    return [resp validateMenuItem:item];
            return true;
        }
        item.title = tabs > 1 ? NSLocalizedString(@"Close Tab", "Menu item title for closing current tab") :
                                NSLocalizedString(@"Close Window", "Menu item title for closing current window");
        return true;
    }
    IF_MENU_TAG("menu.file.close_window") {
        item.hidden = self.currentSideTabsCount < 2;
        return true;
    }
    IF_MENU_TAG("menu.window.show_previous_tab")
        return nc::panel::actions::ShowPreviousTab::ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.window.show_next_tab")
        return nc::panel::actions::ShowNextTab::ValidateMenuItem(self, item);
    IF_MENU_TAG("menu.view.show_tabs") {
        item.title = GlobalConfig().GetBool(g_ConfigGeneralShowTabs) ?
            NSLocalizedString(@"Hide Tab Bar", "Menu item title for hiding tab bar") :
            NSLocalizedString(@"Show Tab Bar", "Menu item title for showing tab bar");
        return true;
    }
    IF_MENU_TAG("menu.view.show_terminal") {
        item.title = NSLocalizedString(@"Show Terminal", "Menu item title for showing terminal");
        return true;
    }
    IF_MENU_TAG("menu.view.switch_dual_single_mode") {
        item.title = m_MainSplitView.anyCollapsed ?
            NSLocalizedString(@"Toggle Dual-Pane Mode", "Menu item title for switching to dual-pane mode") :
            NSLocalizedString(@"Toggle Single-Pane Mode", "Menu item title for switching to single-pane mode");
        return true;
    }
    
    return true;
}

- (IBAction)OnSyncPanels:(id)sender
{
    if(!self.activePanelController || !self.oppositePanelController || m_MainSplitView.anyCollapsedOrOverlayed)
        return;
    
    [self.oppositePanelController GoToDir:self.activePanelController.currentDirectoryPath
                                      vfs:self.activePanelController.vfs
                             select_entry:""
                                    async:true];
}

- (IBAction)OnSwapPanels:(id)sender
{
    if(m_MainSplitView.anyCollapsedOrOverlayed)
        return;
    
    swap(m_LeftPanelControllers, m_RightPanelControllers);
    [m_MainSplitView swapViews];
    [self markRestorableStateAsInvalid];
}

- (IBAction)OnShowTerminal:(id)sender
{
    string path = "";
    if( self.isPanelActive &&
        self.activePanelController.isUniform &&
        self.activePanelController.vfs->IsNativeFS() )
        path = self.activePanelController.currentDirectoryPath;
    [(MainWindowController*)self.window.delegate requestTerminal:path];
}

+ (void)performVFSItemOpenInPanel:(PanelController*)_panel item:(VFSListingItem)_item
{
    assert( _panel != nil && (bool)_item );
    
    if( _item.IsDir() )
        [_panel GoToDir:_item.Path()
                    vfs:_item.Host()
           select_entry:""
                  async:true];
    else
        [_panel GoToDir:_item.Directory()
                    vfs:_item.Host()
           select_entry:_item.Filename()
                  async:true];
}

- (IBAction)OnFileOpenInOppositePanel:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed || !self.activePanelView.item)
        return;
    auto cur = self.activePanelController;
    auto opp = self.oppositePanelController;
    auto item = cur.view.item;
    if( !cur || !opp || !item )
        return;
    
    [self.class performVFSItemOpenInPanel:opp item:item];
}

- (IBAction)OnFileOpenInNewOppositePanelTab:(id)sender
{
    if( !self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed || !self.activePanelView.item )
        return;
    auto cur = self.activePanelController;
    if( !cur )
        return;
    
    auto item = cur.view.item;
    if( !item )
        return;
    
    PanelController *opp = nil;
    if( cur == self.leftPanelController )
        opp = [self spawnNewTabInTabView:m_MainSplitView.rightTabbedHolder.tabView autoDirectoryLoading:false activateNewPanel:false];
    else if( cur == self.rightPanelController )
        opp = [self spawnNewTabInTabView:m_MainSplitView.leftTabbedHolder.tabView autoDirectoryLoading:false activateNewPanel:false];
    if( !opp )
        return;
    
    [self.class performVFSItemOpenInPanel:opp item:item];
}

- (IBAction)onCompressItems:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed) return;
    
    auto entries = self.activePanelController.selectedEntriesOrFocusedEntry;
    if(entries.empty())
        return;
    
    if( !self.oppositePanelController.isUniform )
        return;

    FileCompressOperation *op = [[FileCompressOperation alloc] initWithFiles:move(entries)
                                                                     dstroot:self.oppositePanelController.currentDirectoryPath
                                                                      dstvfs:self.oppositePanelController.vfs];
    op.TargetPanel = self.oppositePanelController;
    [m_OperationsController AddOperation:op];
}

- (IBAction)onCompressItemsHere:(id)sender
{
    if( !self.isPanelActive || !self.activePanelController.isUniform )
        return;
    
    auto entries = self.activePanelController.selectedEntriesOrFocusedEntry;
    if( entries.empty() )
        return;
    
    FileCompressOperation *op = [[FileCompressOperation alloc] initWithFiles:move(entries)
                                                                     dstroot:self.activePanelController.currentDirectoryPath
                                                                      dstvfs:self.activePanelController.vfs];
    op.TargetPanel = self.activePanelController;
    [m_OperationsController AddOperation:op];
}

- (IBAction)OnCreateSymbolicLinkCommand:(id)sender
{
    if( !self.activePanelController || !self.oppositePanelController || !self.oppositePanelController.isUniform )
        return;
    
    auto item = self.activePanelView.item;
    if( !item )
        return;
    
    string source_path = item.Path();
    string link_path = self.oppositePanelController.currentDirectoryPath + (!item.IsDotDot() ? item.Name() : [self activePanelData]->DirectoryPathShort());
    
    FileLinkNewSymlinkSheetController *sheet = [FileLinkNewSymlinkSheetController new];
    [sheet showSheetFor:self.window
             sourcePath:source_path
               linkPath:link_path
      completionHandler:^(NSModalResponse returnCode) {
          if( returnCode == NSModalResponseOK && !sheet.linkPath.empty() ) {
              [m_OperationsController AddOperation:
               [[FileLinkOperation alloc] initWithNewSymbolinkLink:sheet.sourcePath.c_str()
                                                          linkname:sheet.linkPath.c_str()]];
          }}];
}

- (IBAction)OnEditSymbolicLinkCommand:(id)sender
{
    if( !self.activePanelController )
        return;
    
    auto item = self.activePanelView.item;
    if( !item || !item.IsSymlink() )
        return;
    
    FileLinkAlterSymlinkSheetController *sheet = [FileLinkAlterSymlinkSheetController new];
    [sheet showSheetFor:self.window
             sourcePath:item.Symlink()
               linkPath:item.Name()
      completionHandler:^(NSModalResponse returnCode) {
          if(returnCode == NSModalResponseOK)
              [m_OperationsController AddOperation:[[FileLinkOperation alloc] initWithAlteringOfSymbolicLink:sheet.sourcePath.c_str()
                                                                                                    linkname:item.Path().c_str()]
               ];
      }];
}

- (IBAction)OnCreateHardLinkCommand:(id)sender
{
    auto item = self.activePanelView.item;
    if( item.IsDir() || !item.Host()->IsNativeFS() )
        return;
    
    FileLinkNewHardlinkSheetController *sheet = [FileLinkNewHardlinkSheetController new];
    [sheet showSheetFor:self.window withSourceName:item.Name() completionHandler:^(NSModalResponse returnCode) {
                 if( returnCode == NSModalResponseOK ) {
                     string path = sheet.result;
                     if( path.empty() )
                         return;
                     
                     if( path.front() != '/')
                         path = item.Directory() + path;
                     
                     [m_OperationsController AddOperation:
                      [[FileLinkOperation alloc] initWithNewHardLink:item.Path().c_str()
                                                            linkname:path.c_str()
                      ]];
                 }
             }];
}

// when Operation.AddOnFinishHandler will use C++ lambdas - change return type here:
- (void (^)()) refreshBothCurrentControllersLambda
{
    __weak auto cur = self.activePanelController;
    __weak auto opp = self.oppositePanelController;
    auto update_both_panels = [=] {
        dispatch_to_main_queue( [=]{
            [(PanelController*)cur refreshPanel];
            [(PanelController*)opp refreshPanel];
        });
    };
    return update_both_panels;
}

- (IBAction)OnFileCopyCommand:(id)sender{
    if( !self.activePanelController || !self.oppositePanelController )
        return;
    
    auto entries = self.activePanelController.selectedEntriesOrFocusedEntry;
    if( entries.empty() )
        return;
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda;
    
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:self.activePanelController.isUniform ? self.activePanelController.vfs : nullptr
                                             sourceDirectory:self.activePanelController.isUniform ? self.activePanelController.currentDirectoryPath : ""
                                          initialDestination:self.oppositePanelController.isUniform ? self.oppositePanelController.currentDirectoryPath : ""
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:panel::MakeDefaultFileCopyOptions()];
    [mc beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui possibly has fucked up
        
        auto op = [[FileCopyOperation alloc] initWithItems:move(entries) destinationPath:path destinationHost:host options:opts];
        [op AddOnFinishHandler:update_both_panels];        
        [m_OperationsController AddOperation:op];
    }];
}

- (IBAction)OnFileCopyAsCommand:(id)sender{
    if( !self.activePanelController || !self.oppositePanelController )
        return;
    
    // process only current cursor item
    auto item = self.activePanelView.item;
    if( !item || item.IsDotDot() )
        return;

    auto entries = vector<VFSListingItem>({item});
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda;
        
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:item.Host()
                                             sourceDirectory:item.Directory()
                                          initialDestination:item.Filename()
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:panel::MakeDefaultFileCopyOptions()];
    [mc beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui possibly has fucked up
        
        auto op = [[FileCopyOperation alloc] initWithItems:move(entries) destinationPath:path destinationHost:host options:opts];
        [op AddOnFinishHandler:update_both_panels];
        [m_OperationsController AddOperation:op];
    }];
}

- (IBAction)OnFileRenameMoveCommand:(id)sender{
    if( !self.activePanelController || !self.oppositePanelController )
        return;
    
    if( self.activePanelController.isUniform && !self.activePanelController.vfs->IsWritable() )
        return;
    
    auto entries = self.activePanelController.selectedEntriesOrFocusedEntry;
    if( entries.empty() )
        return;
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda;
        
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:self.activePanelController.isUniform ? self.activePanelController.vfs : nullptr
                                             sourceDirectory:self.activePanelController.isUniform ? self.activePanelController.currentDirectoryPath : ""
                                          initialDestination:self.oppositePanelController.isUniform ? self.oppositePanelController.currentDirectoryPath : ""
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:panel::MakeDefaultFileMoveOptions()];
    [mc beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui possibly has fucked up
        
        auto op = [[FileCopyOperation alloc] initWithItems:move(entries) destinationPath:path destinationHost:host options:opts];
        [op AddOnFinishHandler:update_both_panels];
        [m_OperationsController AddOperation:op];
    }];
}

- (IBAction)OnFileRenameMoveAsCommand:(id)sender {
    if( !self.activePanelController || !self.oppositePanelController )
        return;
    
    // process only current cursor item
    auto item = self.activePanelView.item;
    if( !item || item.IsDotDot() || !item.Host()->IsWritable() )
        return;
    
    auto entries = vector<VFSListingItem>({item});
    auto update_both_panels = self.refreshBothCurrentControllersLambda;
    __weak auto cur = self.activePanelController;
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:item.Host()
                                             sourceDirectory:item.Directory()
                                          initialDestination:item.Filename()
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:panel::MakeDefaultFileMoveOptions()];
    [mc beginSheetForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui possibly has fucked up
        
        auto op = [[FileCopyOperation alloc] initWithItems:move(entries) destinationPath:path destinationHost:host options:opts];
        [op AddOnFinishHandler:update_both_panels];
        [op AddOnFinishHandler:^{
            dispatch_to_main_queue( [=]{
                string single_fn_rename = ::path(path).filename().native();
                nc::panel::PanelControllerDelayedSelection req;
                req.filename = single_fn_rename;
                [(PanelController*)cur ScheduleDelayedSelectionChangeFor:req];
            });
        }];
        [m_OperationsController AddOperation:op];
    }];
}

- (IBAction)OnFileNewTab:(id)sender
{
    if(!self.activePanelController)
        return;
    if(self.activePanelController == self.leftPanelController)
       [self addNewTabToTabView:m_MainSplitView.leftTabbedHolder.tabView];
    else if(self.activePanelController == self.rightPanelController)
        [self addNewTabToTabView:m_MainSplitView.rightTabbedHolder.tabView];
}

- (IBAction)performClose:(id)sender
{
    PanelController *cur = self.activePanelController;
    int tabs = 1;
    if( [self isLeftController:cur] )
        tabs = m_MainSplitView.leftTabbedHolder.tabsCount;
    if( [self isRightController:cur] )
        tabs = m_MainSplitView.rightTabbedHolder.tabsCount;

    if(tabs > 1)
        [self closeCurrentTab];
    else
        [self.window performClose:sender];
}

- (IBAction)OnFileCloseWindow:(id)sender
{
    [self.window performClose:sender];
}

- (IBAction)OnWindowShowPreviousTab:(id)sender
{
    nc::panel::actions::ShowPreviousTab::Perform(self, sender);
}

- (IBAction)OnWindowShowNextTab:(id)sender
{
    nc::panel::actions::ShowNextTab::Perform(self, sender);
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    NSString* characters = theEvent.charactersIgnoringModifiers;
    if ( characters.length != 1 )
        return [super performKeyEquivalent:theEvent];
    
    auto kc = theEvent.keyCode;
    auto mod = theEvent.modifierFlags & NSDeviceIndependentModifierFlagsMask;
    mod &= ~NSAlphaShiftKeyMask;
    mod &= ~NSNumericPadKeyMask;
    mod &= ~NSFunctionKeyMask;
    auto unicode = [characters characterAtIndex:0];
    
    // workaround for (shift)+ctrl+tab when it's menu item is disabled. mysterious stuff...
    if( unicode == NSTabCharacter && mod == NSControlKeyMask ) {
        if( nc::panel::actions::ShowNextTab::Predicate(self) )
            return [super performKeyEquivalent:theEvent];
        return true;
    }
    if( unicode == NSTabCharacter && mod == (NSControlKeyMask|NSShiftKeyMask) ) {
        if( nc::panel::actions::ShowPreviousTab::Predicate(self) )
            return [super performKeyEquivalent:theEvent];
        return true;
    }

    // overlapped terminal stuff
    if( ActivationManager::Instance().HasTerminal() ) {
        static ActionsShortcutsManager::ShortCut hk_move_up, hk_move_down, hk_showhide, hk_focus;
        static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater({&hk_move_up, &hk_move_down, &hk_showhide, &hk_focus},
                                                                         {"menu.view.panels_position.move_up", "menu.view.panels_position.move_down", "menu.view.panels_position.showpanels", "menu.view.panels_position.focusterminal"});
        
        if( hk_move_up.IsKeyDown(unicode, kc, mod)  ) {
            [self OnViewPanelsPositionMoveUp:self];
            return true;
        }
        
        if( hk_move_down.IsKeyDown(unicode, kc, mod) ) {
            [self OnViewPanelsPositionMoveDown:self];
            return true;
        }
        
        if( hk_showhide.IsKeyDown(unicode, kc, mod) ) {
            [self OnViewPanelsPositionShowHidePanels:self];
            return true;
        }
        
        if( hk_focus.IsKeyDown(unicode, kc, mod) ) {
            [self OnViewPanelsPositionFocusOverlappedTerminal:self];
            return true;
        }
    }
    
    return [super performKeyEquivalent:theEvent];
}

- (IBAction)OnShowTabs:(id)sender
{
    GlobalConfig().Set( g_ConfigGeneralShowTabs, !GlobalConfig().GetBool(g_ConfigGeneralShowTabs) );
}

- (IBAction)OnViewPanelsPositionMoveUp:(id)sender
{
    [self increaseBottomTerminalGap];
}

- (IBAction)OnViewPanelsPositionMoveDown:(id)sender
{
    [self decreaseBottomTerminalGap];
}

- (IBAction)OnViewPanelsPositionShowHidePanels:(id)sender
{
    if(self.isPanelsSplitViewHidden)
        [self showPanelsSplitView];
    else
        [self hidePanelsSplitView];
}

- (IBAction)OnViewPanelsPositionFocusOverlappedTerminal:(id)sender
{
    [self handleCtrlAltTab];
}

- (IBAction)OnFileFeedFilenameToTerminal:(id)sender
{
    [self feedOverlappedTerminalWithCurrentFilename];
}

- (IBAction)OnFileFeedFilenamesToTerminal:(id)sender
{
    [self feedOverlappedTerminalWithFilenamesMenu];
}

- (IBAction)onExternMenuActionCalled:(id)sender
{
    if( auto menuitem = objc_cast<NSMenuItem>(sender) )
        if( auto rep = objc_cast<ToolsMenuDelegateInfoWrapper>(menuitem.representedObject) )
            if( auto t = rep.object )
                [self runExtTool:t];
}

 - (IBAction)onSwitchDualSinglePaneMode:(id)sender
{
    if( m_MainSplitView.anyCollapsed ) {
        if( m_MainSplitView.isLeftCollapsed )
            [m_MainSplitView expandLeftView];
        else if( m_MainSplitView.isRightCollapsed )
            [m_MainSplitView expandRightView];
    }
    else if( auto apc = self.activePanelController) {
        if( apc == self.leftPanelController )
            [m_MainSplitView collapseRightView];
        else if( apc == self.rightPanelController )
            [m_MainSplitView collapseLeftView];
    }
}

@end
