//
//  MainWindowFilePanelState+Menu.m
//  Files
//
//  Created by Michael G. Kazakov on 19.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/CommonPaths.h>
#include <Utility/NSMenu+Hierarchical.h>
#include "Operations/Link/FileLinkNewSymlinkSheetController.h"
#include "Operations/Link/FileLinkAlterSymlinkSheetController.h"
#include "Operations/Link/FileLinkNewHardlinkSheetController.h"
#include "Operations/Link/FileLinkOperation.h"
#include "Operations/Copy/FileCopyOperation.h"
#include "Operations/Copy/MassCopySheetController.h"
#include "Operations/Delete/FileDeletionOperation.h"
#include "Operations/Compress/FileCompressOperation.h"
#include "Operations/OperationsController.h"
#include "MainWindowFilePanelState+Menu.h"
#include "ActionsShortcutsManager.h"
#include "PanelController.h"
#include "FilePanelMainSplitView.h"
#include "Common.h"
#include "MainWindowController.h"

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
    auto tag = item.tag;
    IF_MENU_TAG("menu.view.swap_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.view.sync_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.file.open_in_opposite_panel")  return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item;
    IF_MENU_TAG("menu.command.compress")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item && !self.activePanelView.item.IsDotDot();
    IF_MENU_TAG("menu.command.link_create_soft")     return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed &&
        self.activePanelView.item && self.activePanelView.item.Host()->IsNativeFS() && self.oppositePanelController.isUniform && self.oppositePanelController.vfs->IsNativeFS();
    IF_MENU_TAG("menu.command.link_create_hard")     return self.isPanelActive && self.activePanelView.item && !self.activePanelView.item.IsDir() && self.activePanelView.item.Host()->IsNativeFS();
    IF_MENU_TAG("menu.command.link_edit")            return self.isPanelActive && self.activePanelView.item && self.activePanelView.item.IsSymlink() && self.activePanelView.item.Host()->IsNativeFS();
    IF_MENU_TAG("menu.command.copy_to")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.copy_as")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.move_to")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.move_as")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.rename_in_place")      return self.isPanelActive && self.activePanelView.item && !self.activePanelView.item.IsDotDot() && self.activePanelView.item.Host()->IsWriteable();
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
    IF_MENU_TAG("menu.window.show_previous_tab")    return self.currentSideTabsCount > 1;
    IF_MENU_TAG("menu.window.show_next_tab")        return self.currentSideTabsCount > 1;
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
    [m_MainSplitView SwapViews];
    
    [self.leftPanelController AttachToControls:m_LeftPanelSpinningIndicator share:m_LeftPanelShareButton];
    [self.rightPanelController AttachToControls:m_RightPanelSpinningIndicator share:m_RightPanelShareButton];
    
    [self markRestorableStateAsInvalid];
}

- (IBAction)OnShowTerminal:(id)sender
{
    string path = "";
    if( self.isPanelActive && self.activePanelController.isUniform && self.activePanelController.vfs->IsNativeFS() )
        path = self.activePanelController.currentDirectoryPath;
    [(MainWindowController*)self.window.delegate RequestTerminal:path];
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

- (IBAction)OnCompressFiles:(id)sender
{
    if(!self.isPanelActive || m_MainSplitView.anyCollapsedOrOverlayed) return;
    
    auto entries = self.activePanelController.selectedEntriesOrFocusedEntry;
    if(entries.empty())
        return;

    FileCompressOperation *op = [[FileCompressOperation alloc] initWithFiles:move(entries)
                                                                     dstroot:self.oppositePanelController.currentDirectoryPath
                                                                      dstvfs:self.oppositePanelController.vfs];
    op.TargetPanel = self.oppositePanelController;
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
            [(PanelController*)cur RefreshDirectory];
            [(PanelController*)opp RefreshDirectory];
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

    FileCopyOperationOptions opts;
    opts.docopy = true;
    
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:self.activePanelController.isUniform ? self.activePanelController.vfs : nullptr
                                             sourceDirectory:self.activePanelController.isUniform ? self.activePanelController.currentDirectoryPath : ""
                                          initialDestination:self.oppositePanelController.isUniform ? self.oppositePanelController.currentDirectoryPath : ""
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:opts];
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
    
    FileCopyOperationOptions opts;
    opts.docopy = true;
    
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:item.Host()
                                             sourceDirectory:item.Directory()
                                          initialDestination:item.Filename()
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:opts];
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
    
    if( self.activePanelController.isUniform && !self.activePanelController.vfs->IsWriteable() )
        return;
    
    auto entries = self.activePanelController.selectedEntriesOrFocusedEntry;
    if( entries.empty() )
        return;
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda;
    
    FileCopyOperationOptions opts;
    opts.docopy = false;
    
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:self.activePanelController.isUniform ? self.activePanelController.vfs : nullptr
                                             sourceDirectory:self.activePanelController.isUniform ? self.activePanelController.currentDirectoryPath : ""
                                          initialDestination:self.oppositePanelController.isUniform ? self.oppositePanelController.currentDirectoryPath : ""
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:opts];
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
    if( !item || item.IsDotDot() || !item.Host()->IsWriteable() )
        return;
    
    FileCopyOperationOptions opts;
    opts.docopy = false;

    auto entries = vector<VFSListingItem>({item});
    auto update_both_panels = self.refreshBothCurrentControllersLambda;
    __weak auto cur = self.activePanelController;
    auto mc = [[MassCopySheetController alloc] initWithItems:entries
                                                   sourceVFS:item.Host()
                                             sourceDirectory:item.Directory()
                                          initialDestination:item.Filename()
                                              destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                            operationOptions:opts];
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
                PanelControllerDelayedSelection req;
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
    [self selectPreviousFilePanelTab];
}

- (IBAction)OnWindowShowNextTab:(id)sender
{
    [self selectNextFilePanelTab];
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
    
    const auto &am = ActionsShortcutsManager::Instance();
    
    // workaround for (shift)+ctrl+tab when it's menu item is disabled. mysterious stuff...
    if( unicode == NSTabCharacter && mod == NSControlKeyMask ) {
        static const int next_tab = ActionsShortcutsManager::Instance().TagFromAction("menu.window.show_next_tab");
        if([NSApplication.sharedApplication.menu itemWithTagHierarchical:next_tab].enabled)
            return [super performKeyEquivalent:theEvent];
        return true;
    }
    if( unicode == NSTabCharacter && mod == (NSControlKeyMask|NSShiftKeyMask) ) {
        static const int prev_tab = ActionsShortcutsManager::Instance().TagFromAction("menu.window.show_previous_tab");
        if([NSApplication.sharedApplication.menu itemWithTagHierarchical:prev_tab].enabled)
            return [super performKeyEquivalent:theEvent];
        return true;
    }

    const auto isshortcut = [&](int tag) {
        if( auto sc = am.ShortCutFromTag(tag) )
            return sc->IsKeyDown(unicode, kc, mod);
        return false;
    };

    // overlapped terminal stuff
    if( configuration::has_terminal ) {
        static const auto filepanels_move_up = am.TagFromAction( "menu.view.panels_position.move_up" );
        if( isshortcut(filepanels_move_up) ) {
            [self OnViewPanelsPositionMoveUp:self];
            return true;
        }
        
        static const auto filepanels_move_down = am.TagFromAction( "menu.view.panels_position.move_down" );
        if( isshortcut(filepanels_move_down) ) {
            [self OnViewPanelsPositionMoveDown:self];
            return true;
        }
        
        static const auto filepanels_showhide = am.TagFromAction( "menu.view.panels_position.showpanels" );
        if( isshortcut(filepanels_showhide) ) {
            [self OnViewPanelsPositionShowHidePanels:self];
            return true;
        }
        
        static const auto filepanels_focusterminal = am.TagFromAction( "menu.view.panels_position.focusterminal" );
        if( isshortcut(filepanels_focusterminal) ) {
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

@end
