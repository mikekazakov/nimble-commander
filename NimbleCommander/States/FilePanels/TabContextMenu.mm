// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.

#include "TabContextMenu.h"
#include "Actions/TabsManagement.h"
#include <NimbleCommander/Core/Alert.h>
#include <unordered_map>
#include <iostream>

using namespace nc::panel;
using ActionsT = std::unordered_map<SEL, std::unique_ptr<actions::StateAction>>;

static const actions::StateAction* ActionBySelector(const ActionsT &_actions, SEL _sel);
static void Perform(const ActionsT &_actions,
                    SEL _sel,
                    MainWindowFilePanelState *_target,
                    id _sender);

@implementation NCPanelTabContextMenu
{
    ActionsT m_Actions;
    MainWindowFilePanelState* m_State;
    PanelController* m_CurrentPanel;
}

- (instancetype) initWithPanel:(PanelController*)_panel
                       ofState:(MainWindowFilePanelState*)_state
{
    self = [super init];
    if(self) {
        m_State = _state;
        m_CurrentPanel = _panel;

        [self buildActions];
        [self buildMenuItems];
    }
    return self;
}

- (void)buildActions
{
    using namespace actions::context;
    m_Actions[@selector(onAddNewTab:)] = std::make_unique<AddNewTab>(m_CurrentPanel);
    m_Actions[@selector(onCloseTab:)] = std::make_unique<CloseTab>(m_CurrentPanel);
    m_Actions[@selector(onCloseOtherTabs:)] = std::make_unique<CloseOtherTabs>(m_CurrentPanel);
}

- (void)buildMenuItems
{
    const auto new_tab = [[NSMenuItem alloc] init];
    new_tab.title = NSLocalizedString(@"New Tab", "");
    new_tab.target = self;
    new_tab.action = @selector(onAddNewTab:);
    [self addItem:new_tab];

    const auto close_tab = [[NSMenuItem alloc] init];
    close_tab.title = NSLocalizedString(@"Close Tab", "");
    close_tab.target = self;
    close_tab.action = @selector(onCloseTab:);
    [self addItem:close_tab];
    
    const auto close_other_tabs = [[NSMenuItem alloc] init];
    close_other_tabs.title = NSLocalizedString(@"Close Other Tabs", "");
    close_other_tabs.target = self;
    close_other_tabs.action = @selector(onCloseOtherTabs:);
    [self addItem:close_other_tabs];
}

- (IBAction)onAddNewTab:(id)sender { [self perform:_cmd for:sender]; }
- (IBAction)onCloseTab:(id)sender { [self perform:_cmd for:sender]; }
- (IBAction)onCloseOtherTabs:(id)sender { [self perform:_cmd for:sender]; }

- (void)perform:(SEL)_sel for:(id)_sender
{
    Perform(m_Actions, _sel, m_State, _sender);
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    try {
        if( const auto action = ActionBySelector(m_Actions, item.action) )
            return action->ValidateMenuItem(m_State, item);
        return true;
    }
    catch(std::exception &e) {
        std::cout << "Exception caught: " << e.what() << std::endl;
    }
    catch(...) {
        std::cout << "Caught an unhandled exception!" << std::endl;
    }
    return false;
}

@end

static const actions::StateAction* ActionBySelector(const ActionsT &_actions, SEL _sel)
{
    if( const auto action = _actions.find(_sel); action != end(_actions) )
        return action->second.get();
        
    return nullptr;
}

static void Perform(const ActionsT &_actions,
                    SEL _sel,
                    MainWindowFilePanelState *_target,
                    id _sender)
{
    if( const auto action = _actions.find(_sel); action != end(_actions) ) {
        try {
            action->second->Perform(_target, _sender);
        }
        catch( std::exception &e ) {
            nc::core::ShowExceptionAlert(e);
        }
        catch(...){
            nc::core::ShowExceptionAlert();
        }
    }
    else {
        std::cerr << "warning - unrecognized selector: " <<
        NSStringFromSelector(_sel).UTF8String << std::endl;
    }
}
