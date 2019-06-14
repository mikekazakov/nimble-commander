// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.

#include "TabsManagement.h"
#include "../MainWindowFilePanelState.h"
#include "../MainWindowFilePanelState+TabsSupport.h"
#include "../Views/FilePanelMainSplitView.h"
#include <NimbleCommander/Core/Alert.h>
#include <Utility/ObjCpp.h>

namespace nc::panel::actions {

static const auto g_CloseTab =
    NSLocalizedString(@"Close Tab", "Menu item title for closing current tab");
static const auto g_CloseWindow =
    NSLocalizedString(@"Close Window", "Menu item title for closing current window");

bool ShowNextTab::Predicate( MainWindowFilePanelState *_target ) const
{
    return _target.currentSideTabsCount > 1;
}

bool ShowNextTab::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem * ) const
{
    return Predicate( _target );
}

void ShowNextTab::Perform( MainWindowFilePanelState *_target, id ) const
{
    [_target selectNextFilePanelTab];
}

bool ShowPreviousTab::Predicate( MainWindowFilePanelState *_target ) const
{
    return _target.currentSideTabsCount > 1;
}

bool ShowPreviousTab::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem * ) const
{
    return Predicate( _target );
}

void ShowPreviousTab::Perform( MainWindowFilePanelState *_target, id ) const
{
    [_target selectPreviousFilePanelTab];
}
    
bool CloseTab::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const
{
    const auto tabs = _target.currentSideTabsCount;
    if( tabs == 0 ) {
        // in this case (no other adequate responders) - pass validation  up
        NSResponder *resp = _target.nextResponder;
        while( objc_cast<AttachedResponder>(resp) != nil )
            resp = resp.nextResponder;
        while( resp != nil ) {
            if( [resp respondsToSelector:_item.action] &&
                [resp respondsToSelector:@selector(validateMenuItem:)] )
                return [resp validateMenuItem:_item];
            resp = resp.nextResponder;            
        }
        return true;
    }
    _item.title = tabs > 1 ? g_CloseTab : g_CloseWindow;
    return Predicate(_target);
}
    
static void AskAboutClosingWindowWithExtraTabs(int _amount,
                                               NSWindow *_window,
                                               std::function<void(NSModalResponse)> _handler )
{
    assert(_window && _handler);
    Alert *dialog = [[Alert alloc] init];
    [dialog addButtonWithTitle:NSLocalizedString(@"Close", "User action to close a window")];
    [dialog addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    auto fmt = NSLocalizedString
    (@"The window has %@ tabs. Are you sure you want to close this window?",
     "Asking user to close window with additional tabs");
    auto msg = [NSString localizedStringWithFormat:fmt, [NSNumber numberWithInt:_amount]];
    dialog.messageText = msg;
    [dialog beginSheetModalForWindow:_window completionHandler:^(NSModalResponse result) {
        _handler(result);
    }];
}
    
void CloseTab::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    const auto act_pc = _target.activePanelController;
    int tabs_on_current_side = 0;
    if( [_target isLeftController:act_pc] )
        tabs_on_current_side = _target.splitView.leftTabbedHolder.tabsCount;
    else if( [_target isRightController:act_pc] )
        tabs_on_current_side = _target.splitView.rightTabbedHolder.tabsCount;
    
    if( tabs_on_current_side > 1 ) {
        [_target closeTabForController:act_pc];
    }
    else {
        int total_tabs = (int)_target.leftControllers.size() + (int)_target.rightControllers.size();
        if( total_tabs > 2 ) {
            auto window = _target.window;
            auto close_callback = [=](NSModalResponse result) {
                if (result != NSAlertFirstButtonReturn) return;
                dispatch_to_main_queue([=]{
                    [window close];
                });
            };
            AskAboutClosingWindowWithExtraTabs( total_tabs, window, close_callback );
        }
        else {
            [_target.window performClose:_sender];
        }
    }
}
    
bool CloseOtherTabs::Predicate( MainWindowFilePanelState *_target ) const
{        
    const auto active_controller = _target.activePanelController;
    if( active_controller == nil )
        return false;

    const auto amount_of_tab_on_this_side = [&]{
        if( [_target isLeftController:active_controller] )
            return (int)_target.leftControllers.size();
        if( [_target isRightController:active_controller] )
            return (int)_target.rightControllers.size();        
        return 0;
    }();
    
    return amount_of_tab_on_this_side > 1;
}
    
void CloseOtherTabs::Perform( MainWindowFilePanelState *_target, id ) const
{
    if( !Predicate(_target) )
        return;
    [_target closeOtherTabsForController:_target.activePanelController]; 
}

bool CloseWindow::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const
{
    _item.hidden = _target.currentSideTabsCount < 2;
    return Predicate(_target);
}
    
void CloseWindow::Perform( MainWindowFilePanelState *_target, id _sender ) const
{
    [_target.window performClose:_sender];
}

void AddNewTab::Perform( MainWindowFilePanelState *_target, id ) const
{
    const auto active_pc = _target.activePanelController;
    if( !active_pc )
        return;
    
    NSTabView *target_tab_view = nil;
    
    if( active_pc == _target.leftPanelController )
        target_tab_view = _target.splitView.leftTabbedHolder.tabView;
    else if( active_pc == _target.rightPanelController )
        target_tab_view = _target.splitView.rightTabbedHolder.tabView;
    
    if( !target_tab_view )
        return;
    
    [_target addNewTabToTabView:target_tab_view];
}

context::AddNewTab::AddNewTab(PanelController *_current_pc):
    m_CurrentPC(_current_pc)
{
}
    
void context::AddNewTab::Perform( MainWindowFilePanelState *_target, id ) const
{
    NSTabView *target_tab_view = nil;
    
    if( [_target isLeftController:m_CurrentPC] )
        target_tab_view = _target.splitView.leftTabbedHolder.tabView;
    else if( [_target isRightController:m_CurrentPC] )
        target_tab_view = _target.splitView.rightTabbedHolder.tabView;
    
    if( !target_tab_view )
        return;
    
    [_target addNewTabToTabView:target_tab_view];
}
    
context::CloseTab::CloseTab(PanelController *_current_pc):
    m_CurrentPC(_current_pc)
{
}

bool context::CloseTab::Predicate( MainWindowFilePanelState *_target ) const
{
    if( [_target isLeftController:m_CurrentPC] )
        return _target.leftControllers.size() > 1;
    if( [_target isRightController:m_CurrentPC] )
        return _target.rightControllers.size() > 1;
    return false;
}

void context::CloseTab::Perform( MainWindowFilePanelState *_target, id ) const
{
    [_target closeTabForController:m_CurrentPC];
}
    
context::CloseOtherTabs::CloseOtherTabs(PanelController *_current_pc):
    m_CurrentPC(_current_pc)
{
}

bool context::CloseOtherTabs::Predicate( MainWindowFilePanelState *_target ) const
{
    if( [_target isLeftController:m_CurrentPC] )
        return _target.leftControllers.size() > 1;
    if( [_target isRightController:m_CurrentPC] )
        return _target.rightControllers.size() > 1;
    return false;
}
    
void context::CloseOtherTabs::Perform( MainWindowFilePanelState *_target, id ) const
{
    [_target closeOtherTabsForController:m_CurrentPC];
}
    
}
