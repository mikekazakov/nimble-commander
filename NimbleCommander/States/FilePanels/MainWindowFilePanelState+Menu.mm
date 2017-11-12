// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/CommonPaths.h>
#include <Utility/NSMenu+Hierarchical.h>
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
#include "Actions/ShowGoToPopup.h"
#include "Actions/ToggleSingleOrDualMode.h"
#include "Actions/ShowTabs.h"
#include "../MainWindowController.h"
#include <Operations/Copying.h>
#include <Operations/CopyingDialog.h>
#include <NimbleCommander/Core/Alert.h>

using namespace nc::core;
using namespace nc::panel;
namespace nc::panel {
static const nc::panel::actions::StateAction *ActionByName(const char* _name) noexcept;
static const nc::panel::actions::StateAction *ActionByTag(int _tag) noexcept;
static void Perform(SEL _sel, MainWindowFilePanelState *_target, id _sender);
}

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
    const auto tag = (int)item.tag;
    if( const auto action = ActionByTag(tag) )
        return action->ValidateMenuItem(self, item);

    IF_MENU_TAG("menu.view.swap_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.view.sync_panels")             return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed;
    IF_MENU_TAG("menu.file.reveal_in_opposite_panel")  return self.isPanelActive && !m_MainSplitView.anyCollapsedOrOverlayed && self.activePanelView.item;
    IF_MENU_TAG("menu.command.copy_to")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.copy_as")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.move_to")              return self.isPanelActive;
    IF_MENU_TAG("menu.command.move_as")              return self.isPanelActive;
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

- (function<void()>) refreshBothCurrentControllersLambda2
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
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda2;
    
    auto mc = [[NCOpsCopyingDialog alloc] initWithItems:entries
                                              sourceVFS:self.activePanelController.isUniform ? self.activePanelController.vfs : nullptr
                                        sourceDirectory:self.activePanelController.isUniform ? self.activePanelController.currentDirectoryPath : ""
                                     initialDestination:self.oppositePanelController.isUniform ? self.oppositePanelController.currentDirectoryPath : ""
                                         destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                       operationOptions:MakeDefaultFileCopyOptions()];
    mc.allowVerification = ActivationManager::Instance().HasCopyVerification();
    [self.mainWindowController beginSheet:mc.window
                        completionHandler:^(NSModalResponse returnCode){
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui invariant is broken

        const auto op = make_shared<nc::ops::Copying>(move(entries), path, host, opts);
        op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, update_both_panels);
        [self.mainWindowController enqueueOperation:op];
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
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda2;
        
    auto mc = [[NCOpsCopyingDialog alloc] initWithItems:entries
                                              sourceVFS:item.Host()
                                        sourceDirectory:item.Directory()
                                     initialDestination:item.Filename()
                                         destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                       operationOptions:MakeDefaultFileCopyOptions()];
    mc.allowVerification = ActivationManager::Instance().HasCopyVerification();
    [self.mainWindowController beginSheet:mc.window
                        completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui invariant is broken
        
        const auto op = make_shared<nc::ops::Copying>(move(entries), path, host, opts);
        op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, update_both_panels);
        __weak PanelController *weak_panel = self.activePanelController;
        op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=]{
            dispatch_to_main_queue( [=]{
                if( PanelController *panel = weak_panel ) {
                    if( panel.isUniform &&
                        panel.currentDirectoryPath == ::path(path).parent_path().native()+"/" ) {
                       nc::panel::DelayedFocusing req;
                       req.filename = ::path(path).filename().native();
                       [(PanelController*)panel scheduleDelayedFocusing:req];
                    }
                }
            });
        });
        [self.mainWindowController enqueueOperation:op];
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
    
    auto update_both_panels = self.refreshBothCurrentControllersLambda2;
        
    auto mc = [[NCOpsCopyingDialog alloc] initWithItems:entries
                                              sourceVFS:self.activePanelController.isUniform ? self.activePanelController.vfs : nullptr
                                        sourceDirectory:self.activePanelController.isUniform ? self.activePanelController.currentDirectoryPath : ""
                                     initialDestination:self.oppositePanelController.isUniform ? self.oppositePanelController.currentDirectoryPath : ""
                                         destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                       operationOptions:MakeDefaultFileMoveOptions()];
    mc.allowVerification = ActivationManager::Instance().HasCopyVerification();
    [self.mainWindowController beginSheet:mc.window
                        completionHandler:^(NSModalResponse returnCode) {
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui invariant is broken
        
        const auto op = make_shared<nc::ops::Copying>(move(entries), path, host, opts);
        op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, update_both_panels);
        [self.mainWindowController enqueueOperation:op];
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
    auto update_both_panels = self.refreshBothCurrentControllersLambda2;
    __weak auto cur = self.activePanelController;
    auto mc = [[NCOpsCopyingDialog alloc] initWithItems:entries
                                              sourceVFS:item.Host()
                                        sourceDirectory:item.Directory()
                                     initialDestination:item.Filename()
                                         destinationVFS:self.oppositePanelController.isUniform ? self.oppositePanelController.vfs : nullptr
                                       operationOptions:MakeDefaultFileMoveOptions()];
    mc.allowVerification = ActivationManager::Instance().HasCopyVerification();
    [self.mainWindowController beginSheet:mc.window
                        completionHandler:^(NSModalResponse returnCode){
        if( returnCode != NSModalResponseOK )
            return;
        
        auto path = mc.resultDestination;
        auto host = mc.resultHost;
        auto opts = mc.resultOptions;
        if( !host || path.empty() )
            return; // ui invariant is broken
        
        const auto op = make_shared<nc::ops::Copying>(move(entries), path, host, opts);
        op->ObserveUnticketed(nc::ops::Operation::NotifyAboutFinish, update_both_panels);
        op->ObserveUnticketed(nc::ops::Operation::NotifyAboutCompletion, [=]{
            dispatch_to_main_queue( [=]{
                string single_fn_rename = ::path(path).filename().native();
                nc::panel::DelayedFocusing req;
                req.filename = single_fn_rename;
                [(PanelController*)cur scheduleDelayedFocusing:req];
            });
        });
        [self.mainWindowController enqueueOperation:op];
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

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    NSString* characters = theEvent.charactersIgnoringModifiers;
    if ( characters.length != 1 )
        return [super performKeyEquivalent:theEvent];
    
    auto mod = theEvent.modifierFlags & NSDeviceIndependentModifierFlagsMask;
    mod &= ~NSAlphaShiftKeyMask;
    mod &= ~NSNumericPadKeyMask;
    mod &= ~NSFunctionKeyMask;
    auto unicode = [characters characterAtIndex:0];
    
    // workaround for (shift)+ctrl+tab when its menu item is disabled, so NSWindow won't steal
    // the keystroke. This is a bad design choice, since it assumes Ctrl+Tab/Shift+Ctrl+Tab for
    // tabs switching, which might not be true for custom key bindings.
    if( unicode == NSTabCharacter && mod == NSControlKeyMask ) {
        if( ActionByName("menu.window.show_next_tab")->Predicate(self) )
            return [super performKeyEquivalent:theEvent];
        return true;
    }
    if( unicode == NSTabCharacter && mod == (NSControlKeyMask|NSShiftKeyMask ) ) {
        if( ActionByName("menu.window.show_previous_tab")->Predicate(self) )
            return [super performKeyEquivalent:theEvent];
        return true;
    }

    // overlapped terminal stuff
    static const auto has_terminal = ActivationManager::Instance().HasTerminal();
    if( has_terminal ) {
        static ActionsShortcutsManager::ShortCut hk_move_up, hk_move_down, hk_showhide, hk_focus;
        static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater({&hk_move_up, &hk_move_down, &hk_showhide, &hk_focus},
                                                                         {"menu.view.panels_position.move_up", "menu.view.panels_position.move_down", "menu.view.panels_position.showpanels", "menu.view.panels_position.focusterminal"});
        
        if( hk_move_up.IsKeyDown(unicode, mod)  ) {
            [self OnViewPanelsPositionMoveUp:self];
            return true;
        }
        
        if( hk_move_down.IsKeyDown(unicode, mod) ) {
            [self OnViewPanelsPositionMoveDown:self];
            return true;
        }
        
        if( hk_showhide.IsKeyDown(unicode, mod) ) {
            [self OnViewPanelsPositionShowHidePanels:self];
            return true;
        }
        
        if( hk_focus.IsKeyDown(unicode, mod) ) {
            [self OnViewPanelsPositionFocusOverlappedTerminal:self];
            return true;
        }
    }
    
    return [super performKeyEquivalent:theEvent];
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

- (IBAction)onSwitchDualSinglePaneMode:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onLeftPanelGoToButtonAction:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onRightPanelGoToButtonAction:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnWindowShowPreviousTab:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnWindowShowNextTab:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnShowTabs:(id)sender{ Perform(_cmd, self, sender); }

@end

using namespace nc::panel::actions;
namespace nc::panel {

static const tuple<const char*, SEL, const StateAction *> g_Wiring[] = {
{"menu.go.left_panel",                  @selector(onLeftPanelGoToButtonAction:),    new ShowLeftGoToPopup},
{"menu.go.right_panel",                 @selector(onRightPanelGoToButtonAction:),   new ShowRightGoToPopup},
{"menu.view.switch_dual_single_mode",   @selector(onSwitchDualSinglePaneMode:),     new ToggleSingleOrDualMode},
{"menu.window.show_previous_tab",       @selector(OnWindowShowPreviousTab:),        new ShowPreviousTab},
{"menu.window.show_next_tab",           @selector(OnWindowShowNextTab:),            new ShowNextTab},
{"menu.view.show_tabs",                 @selector(OnShowTabs:),                     new ShowTabs}
};

static const nc::panel::actions::StateAction *ActionByName(const char* _name) noexcept
{
    static const auto actions = []{
        unordered_map<string, const StateAction*> m;
        for( auto &a: g_Wiring )
            if( get<0>(a)[0] != 0 )
                m.emplace( get<0>(a), get<2>(a) );
        return m;
    }();
    const auto v = actions.find(_name);
    return v == end(actions) ? nullptr : v->second;
}

static const StateAction *ActionByTag(int _tag) noexcept
{
    static const auto actions = []{
        unordered_map<int, const StateAction*> m;
        auto &am = ActionsShortcutsManager::Instance();
        for( auto &a: g_Wiring )
            if( get<0>(a)[0] != 0 ) {
                if( auto tag = am.TagFromAction(get<0>(a)); tag >= 0 )
                    m.emplace( tag, get<2>(a) );
                else
                    cerr << "warning - unrecognized action: " << get<0>(a) << endl;
            }
        return m;
    }();
    const auto v = actions.find(_tag);
    return v == end(actions) ? nullptr : v->second;
}

static void Perform(SEL _sel, MainWindowFilePanelState *_target, id _sender)
{
    static const auto actions = []{
        unordered_map<SEL, const StateAction*> m;
        for( auto &a: g_Wiring )
            m.emplace( get<1>(a), get<2>(a) );
        return m;
    }();

    if( const auto action = actions.find(_sel); action != end(actions)  ) {
        try {
            action->second->Perform(_target, _sender);
        }
        catch( exception &e ) {
            ShowExceptionAlert(e);
        }
        catch(...){
            ShowExceptionAlert();
        }
    }
    else {
        cerr << "warning - unrecognized selector: " <<
            NSStringFromSelector(_sel).UTF8String << endl;
    }
}

}
