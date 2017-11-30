// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "MainWindowFilePanelState+Menu.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Bootstrap/ActivationManager.h>
#include <NimbleCommander/States/FilePanels/ToolsMenuDelegate.h>
#include "Actions/TabsManagement.h"
#include "Actions/ShowGoToPopup.h"
#include "Actions/ToggleSingleOrDualMode.h"
#include "Actions/ShowTabs.h"
#include "Actions/CopyFile.h"
#include "Actions/RevealInOppositePanel.h"
#include "Actions/ShowTerminal.h"
#include "Actions/SyncPanels.h"
#include <NimbleCommander/Core/Alert.h>

using namespace nc::core;
using namespace nc::panel;
namespace nc::panel {
static const nc::panel::actions::StateAction *ActionByName(const char* _name) noexcept;
static const nc::panel::actions::StateAction *ActionByTag(int _tag) noexcept;
static void Perform(SEL _sel, MainWindowFilePanelState *_target, id _sender);
static bool Validate(MainWindowFilePanelState *_target, NSMenuItem *_item) noexcept;
}

@implementation MainWindowFilePanelState (Menu)

- (BOOL) validateMenuItem:(NSMenuItem *)_item
{
    return Validate(self, _item);
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    NSString* characters = theEvent.charactersIgnoringModifiers;
    if ( characters.length != 1 )
        return [super performKeyEquivalent:theEvent];
    
    constexpr auto mask = NSDeviceIndependentModifierFlagsMask &
                    ~(NSAlphaShiftKeyMask | NSNumericPadKeyMask | NSFunctionKeyMask);
    const auto mod = theEvent.modifierFlags & mask;
    const auto unicode = [characters characterAtIndex:0];
    
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
        static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater(
            {&hk_move_up, &hk_move_down, &hk_showhide, &hk_focus},
            {"menu.view.panels_position.move_up", "menu.view.panels_position.move_down",
             "menu.view.panels_position.showpanels", "menu.view.panels_position.focusterminal"});
        
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

- (IBAction)OnSwapPanels:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnSyncPanels:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnShowTerminal:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)performClose:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnFileCloseWindow:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnFileNewTab:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onSwitchDualSinglePaneMode:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onLeftPanelGoToButtonAction:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)onRightPanelGoToButtonAction:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnWindowShowPreviousTab:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnWindowShowNextTab:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnShowTabs:(id)sender{ Perform(_cmd, self, sender); }
- (IBAction)OnFileCopyCommand:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnFileCopyAsCommand:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnFileRenameMoveCommand:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnFileRenameMoveAsCommand:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnFileOpenInOppositePanel:(id)sender { Perform(_cmd, self, sender); }
- (IBAction)OnFileOpenInNewOppositePanelTab:(id)sender { Perform(_cmd, self, sender); }

@end

using namespace nc::panel::actions;
namespace nc::panel {

static const tuple<const char*, SEL, const StateAction *> g_Wiring[] = {
{"menu.file.new_tab",                       @selector(OnFileNewTab:),                   new AddNewTab},
{"menu.file.close",                         @selector(performClose:),                   new CloseTab},
{"menu.file.close_window",                  @selector(OnFileCloseWindow:),              new CloseWindow},
{"menu.go.left_panel",                      @selector(onLeftPanelGoToButtonAction:),    new ShowLeftGoToPopup},
{"menu.go.right_panel",                     @selector(onRightPanelGoToButtonAction:),   new ShowRightGoToPopup},
{"menu.view.switch_dual_single_mode",       @selector(onSwitchDualSinglePaneMode:),     new ToggleSingleOrDualMode},
{"menu.window.show_previous_tab",           @selector(OnWindowShowPreviousTab:),        new ShowPreviousTab},
{"menu.window.show_next_tab",               @selector(OnWindowShowNextTab:),            new ShowNextTab},
{"menu.view.show_tabs",                     @selector(OnShowTabs:),                     new ShowTabs},
{"menu.view.show_terminal",                 @selector(OnShowTerminal:),                 new ShowTerminal},
{"menu.view.sync_panels",                   @selector(OnSyncPanels:),                   new SyncPanels},
{"menu.view.swap_panels",                   @selector(OnSwapPanels:),                   new SwapPanels},
{"menu.command.copy_to",                    @selector(OnFileCopyCommand:),              new CopyTo},
{"menu.command.copy_as",                    @selector(OnFileCopyAsCommand:),            new CopyAs},
{"menu.command.move_to",                    @selector(OnFileRenameMoveCommand:),        new MoveTo},
{"menu.command.move_as",                    @selector(OnFileRenameMoveAsCommand:),      new MoveAs},
{"menu.file.reveal_in_opposite_panel",      @selector(OnFileOpenInOppositePanel:),      new RevealInOppositePanel},
{"menu.file.reveal_in_opposite_panel_tab",  @selector(OnFileOpenInNewOppositePanelTab:),new RevealInOppositePanelTab},
};

static const StateAction *ActionByName(const char* _name) noexcept
{
    static const auto actions = []{
        unordered_map<string, const StateAction*> m;
        for( const auto &a: g_Wiring )
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
        const auto &am = ActionsShortcutsManager::Instance();
        for( const auto &a: g_Wiring )
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
        for( const auto &a: g_Wiring )
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
    
static bool Validate(MainWindowFilePanelState *_target, NSMenuItem *_item) noexcept
{
    try {
        if( const auto action = ActionByTag( (int)_item.tag ) )
            return action->ValidateMenuItem(_target, _item);
        return true;
    }
    catch(exception &e) {
        cout << "Exception caught: " << e.what() << endl;
    }
    catch(...) {
        cout << "Caught an unhandled exception!" << endl;
    }
    return false;
}

}
