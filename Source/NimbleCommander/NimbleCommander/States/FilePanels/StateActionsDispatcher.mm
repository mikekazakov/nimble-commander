// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "StateActionsDispatcher.h"
#include "Actions/DefaultAction.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/Alert.h>
#include "MainWindowFilePanelState.h"
#include "MainWindowFilePanelState+OverlappedTerminalSupport.h"
#include <iostream>

using namespace nc::core;
using namespace nc::panel;

namespace nc::panel {
static const actions::StateAction *ActionBySel(SEL _sel, const StateActionsMap &_map) noexcept;
static void Perform(SEL _sel, const StateActionsMap &_map, MainWindowFilePanelState *_target, id _sender);
} // namespace nc::panel

@implementation NCPanelsStateActionsDispatcher {
    __unsafe_unretained MainWindowFilePanelState *m_FS;
    const nc::panel::StateActionsMap *m_AM;
    ActionsShortcutsManager::ShortCut m_HKFocusLeft;
    ActionsShortcutsManager::ShortCut m_HKFocusRight;
    ActionsShortcutsManager::ShortCut m_HKMoveUp;
    ActionsShortcutsManager::ShortCut m_HKMoveDown;
    ActionsShortcutsManager::ShortCut m_HKShow;
    ActionsShortcutsManager::ShortCut m_HKFocusTerminal;
    std::unique_ptr<ActionsShortcutsManager::ShortCutsUpdater> m_ShortCutsUpdater;
}
@synthesize hasTerminal;

- (instancetype)initWithState:(MainWindowFilePanelState *)_state
                andActionsMap:(const nc::panel::StateActionsMap &)_actions_map
{
    if( self = [super init] ) {
        m_FS = _state;
        m_AM = &_actions_map;
        m_ShortCutsUpdater = std::make_unique<ActionsShortcutsManager::ShortCutsUpdater>(
            std::initializer_list<ActionsShortcutsManager::ShortCutsUpdater::UpdateTarget>{
                {&m_HKFocusLeft, "panel.focus_left_panel"},
                {&m_HKFocusRight, "panel.focus_right_panel"},
                {&m_HKMoveUp, "menu.view.panels_position.move_up"},
                {&m_HKMoveDown, "menu.view.panels_position.move_down"},
                {&m_HKShow, "menu.view.panels_position.showpanels"},
                {&m_HKFocusTerminal, "menu.view.panels_position.focusterminal"}});
    }
    return self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)item
{
    try {
        if( const auto action = ActionBySel(item.action, *m_AM) )
            return action->ValidateMenuItem(m_FS, item);
        return true;
    } catch( const std::exception &e ) {
        std::cerr << "validateMenuItem has caught an exception: " << e.what() << std::endl;
    } catch( ... ) {
        std::cerr << "validateMenuItem has caught an unknown exception!" << std::endl;
    }
    return false;
}

- (bool)validateActionBySelector:(SEL)_selector
{
    if( const auto action = ActionBySel(_selector, *m_AM) ) {
        try {
            return action->Predicate(m_FS);
        } catch( const std::exception &e ) {
            std::cerr << "validateActionBySelector has caught an exception: " << e.what() << std::endl;
        } catch( ... ) {
            std::cerr << "validateActionBySelector has caught an unknown exception!" << std::endl;
        }
        return false;
    }
    return false;
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
    NSString *characters = theEvent.charactersIgnoringModifiers;
    if( characters.length != 1 )
        return [super performKeyEquivalent:theEvent];

    constexpr auto mask = NSEventModifierFlagDeviceIndependentFlagsMask &
                          ~(NSEventModifierFlagCapsLock | NSEventModifierFlagNumericPad | NSEventModifierFlagFunction);
    const auto mod = theEvent.modifierFlags & mask;
    const auto unicode = [characters characterAtIndex:0];

    // workaround for (shift)+ctrl+tab when its menu item is disabled, so NSWindow won't steal
    // the keystroke. This is a bad design choice, since it assumes Ctrl+Tab/Shift+Ctrl+Tab for
    // tabs switching, which might not be true for custom key bindings.
    if( unicode == NSTabCharacter && mod == NSEventModifierFlagControl ) {
        if( ActionBySel(@selector(OnWindowShowNextTab:), *m_AM)->Predicate(m_FS) )
            return [super performKeyEquivalent:theEvent];
        return true;
    }
    if( unicode == NSTabCharacter && mod == (NSEventModifierFlagControl | NSEventModifierFlagShift) ) {
        if( ActionBySel(@selector(OnWindowShowPreviousTab:), *m_AM)->Predicate(m_FS) )
            return [super performKeyEquivalent:theEvent];
        return true;
    }

    const auto event_data = nc::utility::ActionShortcut::EventData(theEvent);
    if( m_HKFocusLeft.IsKeyDown(event_data) ) {
        [self executeBySelectorIfValidOrBeep:@selector(onFocusLeftPanel:) withSender:self];
        return true;
    }

    if( m_HKFocusRight.IsKeyDown(event_data) ) {
        [self executeBySelectorIfValidOrBeep:@selector(onFocusRightPanel:) withSender:self];
        return true;
    }

    // overlapped terminal stuff
    if( hasTerminal ) {
        if( m_HKMoveUp.IsKeyDown(event_data) ) {
            [self executeBySelectorIfValidOrBeep:@selector(OnViewPanelsPositionMoveUp:) withSender:self];
            return true;
        }

        if( m_HKMoveDown.IsKeyDown(event_data) ) {
            [self executeBySelectorIfValidOrBeep:@selector(OnViewPanelsPositionMoveDown:) withSender:self];
            return true;
        }

        if( m_HKShow.IsKeyDown(event_data) ) {
            [self executeBySelectorIfValidOrBeep:@selector(OnViewPanelsPositionShowHidePanels:) withSender:self];
            return true;
        }

        if( m_HKFocusTerminal.IsKeyDown(event_data) ) {
            [self executeBySelectorIfValidOrBeep:@selector(OnViewPanelsPositionFocusOverlappedTerminal:)
                                      withSender:self];
            return true;
        }
    }

    return [super performKeyEquivalent:theEvent];
}

- (void)executeBySelectorIfValidOrBeep:(SEL)_selector withSender:(id)_sender
{
    const auto is_valid = [self validateActionBySelector:_selector];
    if( is_valid )
        Perform(_selector, *m_AM, m_FS, _sender);
    else
        NSBeep();
}

- (IBAction)OnFileFeedFilenameToTerminal:(id) [[maybe_unused]] _sender
{
    [m_FS feedOverlappedTerminalWithCurrentFilename];
}

- (IBAction)OnFileFeedFilenamesToTerminal:(id) [[maybe_unused]] _sender
{
    [m_FS feedOverlappedTerminalWithFilenamesMenu];
}

#define PERFORM Perform(_cmd, *m_AM, m_FS, sender)

- (IBAction)OnViewPanelsPositionFocusOverlappedTerminal:(id)sender
{
    PERFORM;
}
- (IBAction)OnViewPanelsPositionMoveUp:(id)sender
{
    PERFORM;
}
- (IBAction)OnViewPanelsPositionMoveDown:(id)sender
{
    PERFORM;
}
- (IBAction)OnViewPanelsPositionShowHidePanels:(id)sender
{
    PERFORM;
}
- (IBAction)OnSwapPanels:(id)sender
{
    PERFORM;
}
- (IBAction)OnSyncPanels:(id)sender
{
    PERFORM;
}
- (IBAction)OnShowTerminal:(id)sender
{
    PERFORM;
}
- (IBAction)performClose:(id)sender
{
    PERFORM;
}
- (IBAction)onFileCloseOtherTabs:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileCloseWindow:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileNewTab:(id)sender
{
    PERFORM;
}
- (IBAction)onSwitchDualSinglePaneMode:(id)sender
{
    PERFORM;
}
- (IBAction)onLeftPanelGoToButtonAction:(id)sender
{
    PERFORM;
}
- (IBAction)onRightPanelGoToButtonAction:(id)sender
{
    PERFORM;
}
- (IBAction)OnWindowShowPreviousTab:(id)sender
{
    PERFORM;
}
- (IBAction)OnWindowShowNextTab:(id)sender
{
    PERFORM;
}
- (IBAction)OnShowTabs:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileCopyCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileCopyAsCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileRenameMoveCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileRenameMoveAsCommand:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileOpenInOppositePanel:(id)sender
{
    PERFORM;
}
- (IBAction)OnFileOpenInNewOppositePanelTab:(id)sender
{
    PERFORM;
}
- (IBAction)onExecuteExternalTool:(id)sender
{
    PERFORM;
}
- (IBAction)onFocusLeftPanel:(id)sender
{
    PERFORM;
}
- (IBAction)onFocusRightPanel:(id)sender
{
    PERFORM;
}
#undef PERFORM

@end

using namespace nc::panel::actions;
namespace nc::panel {

static const actions::StateAction *ActionBySel(SEL _sel, const StateActionsMap &_map) noexcept
{
    const auto action = _map.find(_sel);
    return action == end(_map) ? nullptr : action->second.get();
}

static void Perform(SEL _sel, const StateActionsMap &_map, MainWindowFilePanelState *_target, id _sender)
{
    if( const auto action = ActionBySel(_sel, _map) ) {
        try {
            action->Perform(_target, _sender);
        } catch( const std::exception &e ) {
            ShowExceptionAlert(e);
        } catch( ... ) {
            ShowExceptionAlert();
        }
    }
    else {
        std::cerr << "warning - unrecognized selector: " << NSStringFromSelector(_sel).UTF8String << std::endl;
    }
}

} // namespace nc::panel
