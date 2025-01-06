// Copyright (C) 2018-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#include "StateActionsDispatcher.h"
#include "Actions/DefaultAction.h"
#include <Utility/ActionsShortcutsManager.h>
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
    const nc::utility::ActionsShortcutsManager *m_ActionsShortcutsManager;
}
@synthesize hasTerminal;

- (instancetype)initWithState:(MainWindowFilePanelState *)_state
                    actionsMap:(const nc::panel::StateActionsMap &)_actions_map
    andActionsShortcutsManager:(const nc::utility::ActionsShortcutsManager &)_action_shortcuts_manager
{
    self = [super init];
    if( self ) {
        m_FS = _state;
        m_AM = &_actions_map;
        m_ActionsShortcutsManager = &_action_shortcuts_manager;
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
            return action->Predicate(m_FS);
        } catch( const std::exception &e ) {
            std::cerr << "validateActionBySelector has caught an exception: " << e.what() << '\n';
        } catch( ... ) {
            std::cerr << "validateActionBySelector has caught an unknown exception!" << '\n';
        }
        return false;
    }
    return false;
}

- (BOOL)performKeyEquivalent:(NSEvent *)_event
{
    using ASM = nc::utility::ActionsShortcutsManager;
    struct Tags {
        int FocusLeft = -1;
        int FocusRight = -1;
        int MoveUp = -1;
        int MoveDown = -1;
        int Show = -1;
        int FocusTerminal = -1;
    };
    static const Tags tags = [&] {
        Tags t;
        t.FocusLeft = m_ActionsShortcutsManager->TagFromAction("panel.focus_left_panel").value();
        t.FocusRight = m_ActionsShortcutsManager->TagFromAction("panel.focus_right_panel").value();
        t.MoveUp = m_ActionsShortcutsManager->TagFromAction("menu.view.panels_position.move_up").value();
        t.MoveDown = m_ActionsShortcutsManager->TagFromAction("menu.view.panels_position.move_down").value();
        t.Show = m_ActionsShortcutsManager->TagFromAction("menu.view.panels_position.showpanels").value();
        t.FocusTerminal = m_ActionsShortcutsManager->TagFromAction("menu.view.panels_position.focusterminal").value();
        return t;
    }();

    NSString *characters = _event.charactersIgnoringModifiers;
    if( characters.length != 1 )
        return [super performKeyEquivalent:_event];

    constexpr auto mask = NSEventModifierFlagDeviceIndependentFlagsMask &
                          ~(NSEventModifierFlagCapsLock | NSEventModifierFlagNumericPad | NSEventModifierFlagFunction);
    const auto mod = _event.modifierFlags & mask;
    const auto unicode = [characters characterAtIndex:0];

    // workaround for (shift)+ctrl+tab when its menu item is disabled, so NSWindow won't steal
    // the keystroke. This is a bad design choice, since it assumes Ctrl+Tab/Shift+Ctrl+Tab for
    // tabs switching, which might not be true for custom key bindings.
    if( unicode == NSTabCharacter && mod == NSEventModifierFlagControl ) {
        if( ActionBySel(@selector(OnWindowShowNextTab:), *m_AM)->Predicate(m_FS) )
            return [super performKeyEquivalent:_event];
        return true;
    }
    if( unicode == NSTabCharacter && mod == (NSEventModifierFlagControl | NSEventModifierFlagShift) ) {
        if( ActionBySel(@selector(OnWindowShowPreviousTab:), *m_AM)->Predicate(m_FS) )
            return [super performKeyEquivalent:_event];
        return true;
    }

    const std::optional<int> event_action_tag = m_ActionsShortcutsManager->FirstOfActionTagsFromShortcut(
        {reinterpret_cast<const int *>(&tags), sizeof(tags) / sizeof(int)}, ASM::Shortcut::EventData(_event));

    if( event_action_tag == tags.FocusLeft ) {
        [self executeBySelectorIfValidOrBeep:@selector(onFocusLeftPanel:) withSender:self];
        return true;
    }

    if( event_action_tag == tags.FocusRight ) {
        [self executeBySelectorIfValidOrBeep:@selector(onFocusRightPanel:) withSender:self];
        return true;
    }

    // overlapped terminal stuff
    if( hasTerminal ) {
        if( event_action_tag == tags.MoveUp ) {
            [self executeBySelectorIfValidOrBeep:@selector(OnViewPanelsPositionMoveUp:) withSender:self];
            return true;
        }

        if( event_action_tag == tags.MoveDown ) {
            [self executeBySelectorIfValidOrBeep:@selector(OnViewPanelsPositionMoveDown:) withSender:self];
            return true;
        }

        if( event_action_tag == tags.Show ) {
            [self executeBySelectorIfValidOrBeep:@selector(OnViewPanelsPositionShowHidePanels:) withSender:self];
            return true;
        }

        if( event_action_tag == tags.FocusTerminal ) {
            [self executeBySelectorIfValidOrBeep:@selector(OnViewPanelsPositionFocusOverlappedTerminal:)
                                      withSender:self];
            return true;
        }
    }

    return [super performKeyEquivalent:_event];
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
        std::cerr << "warning - unrecognized selector: " << NSStringFromSelector(_sel).UTF8String << '\n';
    }
}

} // namespace nc::panel
