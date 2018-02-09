// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "StateActionsDispatcher.h"
#include "Actions/DefaultAction.h"
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <NimbleCommander/Core/Alert.h>
#include "MainWindowFilePanelState.h"
#include "MainWindowFilePanelState+OverlappedTerminalSupport.h"

using namespace nc::core;
using namespace nc::panel;

namespace nc::panel {
    
static const actions::StateAction *ActionBySel(SEL _sel, const StateActionsMap &_map) noexcept;
static void Perform(SEL _sel, const StateActionsMap &_map,
                    MainWindowFilePanelState *_target, id _sender);
}

@implementation NCPanelsStateActionsDispatcher
{
    __unsafe_unretained MainWindowFilePanelState *m_FS;
    const nc::panel::StateActionsMap *m_AM;
}

- (instancetype)initWithState:(MainWindowFilePanelState*)_state
                andActionsMap:(const nc::panel::StateActionsMap&)_actions_map
{
    if( self = [super init] ) {
        m_FS = _state;
        m_AM = &_actions_map;
    }
    return self;
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    try {
        if( const auto action = ActionBySel(item.action, *m_AM) )
            return action->ValidateMenuItem(m_FS, item);
        return true;
    }
    catch(exception &e) {
        cerr << "validateMenuItem has caught an exception: " << e.what() << endl;
    }
    catch(...) {
        cerr << "validateMenuItem has caught an unknown exception!" << endl;
    }
    return false;
}

- (bool) validateActionBySelector:(SEL)_selector
{
    if( const auto action = ActionBySel(_selector, *m_AM) ) {
        try {
            return action->Predicate(m_FS);
        }
        catch(exception &e) {
            cerr << "validateActionBySelector has caught an exception: " << e.what() << endl;
        }
        catch(...) {
            cerr << "validateActionBySelector has caught an unknown exception!" << endl;
        }
        return false;
    }
    return false;
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
        if( ActionBySel(@selector(OnWindowShowNextTab:), *m_AM)->Predicate(m_FS) )
            return [super performKeyEquivalent:theEvent];
        return true;
    }
    if( unicode == NSTabCharacter && mod == (NSControlKeyMask|NSShiftKeyMask ) ) {
        if( ActionBySel(@selector(OnWindowShowPreviousTab:), *m_AM)->Predicate(m_FS) )
            return [super performKeyEquivalent:theEvent];
        return true;
    }
    
    // overlapped terminal stuff
    if( _hasTerminal ) {
        static ActionsShortcutsManager::ShortCut hk_move_up, hk_move_down, hk_showhide, hk_focus;
        static ActionsShortcutsManager::ShortCutsUpdater hotkeys_updater
        ({&hk_move_up, &hk_move_down, &hk_showhide, &hk_focus},
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
    [m_FS increaseBottomTerminalGap];
}

- (IBAction)OnViewPanelsPositionMoveDown:(id)sender
{
    [m_FS decreaseBottomTerminalGap];
}

- (IBAction)OnViewPanelsPositionShowHidePanels:(id)sender
{
    if(m_FS.isPanelsSplitViewHidden)
        [m_FS showPanelsSplitView];
    else
        [m_FS hidePanelsSplitView];
}

- (IBAction)OnViewPanelsPositionFocusOverlappedTerminal:(id)sender
{
    [m_FS handleCtrlAltTab];
}

- (IBAction)OnFileFeedFilenameToTerminal:(id)sender
{
    [m_FS feedOverlappedTerminalWithCurrentFilename];
}

- (IBAction)OnFileFeedFilenamesToTerminal:(id)sender
{
    [m_FS feedOverlappedTerminalWithFilenamesMenu];
}

#define PERFORM Perform(_cmd, *m_AM, m_FS, sender)

- (IBAction)OnSwapPanels:(id)sender { PERFORM; }
- (IBAction)OnSyncPanels:(id)sender { PERFORM; }
- (IBAction)OnShowTerminal:(id)sender { PERFORM; }
- (IBAction)performClose:(id)sender { PERFORM; }
- (IBAction)OnFileCloseWindow:(id)sender { PERFORM; }
- (IBAction)OnFileNewTab:(id)sender { PERFORM; }
- (IBAction)onSwitchDualSinglePaneMode:(id)sender { PERFORM; }
- (IBAction)onLeftPanelGoToButtonAction:(id)sender { PERFORM; }
- (IBAction)onRightPanelGoToButtonAction:(id)sender { PERFORM; }
- (IBAction)OnWindowShowPreviousTab:(id)sender { PERFORM; }
- (IBAction)OnWindowShowNextTab:(id)sender { PERFORM; }
- (IBAction)OnShowTabs:(id)sender{ PERFORM; }
- (IBAction)OnFileCopyCommand:(id)sender { PERFORM; }
- (IBAction)OnFileCopyAsCommand:(id)sender { PERFORM; }
- (IBAction)OnFileRenameMoveCommand:(id)sender { PERFORM; }
- (IBAction)OnFileRenameMoveAsCommand:(id)sender { PERFORM; }
- (IBAction)OnFileOpenInOppositePanel:(id)sender { PERFORM; }
- (IBAction)OnFileOpenInNewOppositePanelTab:(id)sender { PERFORM; }
- (IBAction)onExecuteExternalTool:(id)sender { PERFORM; }

#undef PERFORM

@end

using namespace nc::panel::actions;
namespace nc::panel {
    
static const actions::StateAction *ActionBySel(SEL _sel, const StateActionsMap &_map) noexcept
{
    const auto action = _map.find(_sel);
    return action == end(_map) ? nullptr : action->second.get();
}
    
static void Perform(SEL _sel, const StateActionsMap &_map,
                    MainWindowFilePanelState *_target, id _sender)
{
    if( const auto action = ActionBySel(_sel, _map) ) {
        try {
            action->Perform(_target, _sender);
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
