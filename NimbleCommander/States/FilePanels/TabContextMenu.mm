// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.

#include "TabContextMenu.h"
#include "Actions/TabsManagement.h"
#include <NimbleCommander/Core/Alert.h>

using namespace nc::panel;
using ActionsT = unordered_map<SEL, unique_ptr<actions::StateAction>>;

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
        self.delegate = self;
        m_State = _state;
        m_CurrentPanel = _panel;

        [self buildActions];
        [self buildMenuItems];
    }
    return self;
}

- (void)buildActions
{
    m_Actions[@selector(onAddNewTab:)] = make_unique<actions::context::AddNewTab>(m_CurrentPanel);
    

}

- (void)buildMenuItems
{
    const auto new_tab = [[NSMenuItem alloc] init];
    new_tab.title = NSLocalizedString(@"New Tab", "");
    new_tab.target = self;
    new_tab.action = @selector(onAddNewTab:);
    [self addItem:new_tab];
    
}

- (IBAction)onAddNewTab:(id)sender
{
    [self perform:_cmd for:sender];
}

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
    catch(exception &e) {
        cout << "Exception caught: " << e.what() << endl;
    }
    catch(...) {
        cout << "Caught an unhandled exception!" << endl;
    }
    return false;
}

@end

static const actions::StateAction* ActionBySelector(const ActionsT &_actions, SEL _sel)
{
    if( const auto action = _actions.find(_sel); action != end(_actions)  )
        return action->second.get();
        
    return nullptr;
}

static void Perform(const ActionsT &_actions,
                    SEL _sel,
                    MainWindowFilePanelState *_target,
                    id _sender)
{
    if( const auto action = _actions.find(_sel); action != end(_actions)  ) {
        try {
            action->second->Perform(_target, _sender);
        }
        catch( exception &e ) {
            nc::core::ShowExceptionAlert(e);
        }
        catch(...){
            nc::core::ShowExceptionAlert();
        }
    }
    else {
        cerr << "warning - unrecognized selector: " <<
        NSStringFromSelector(_sel).UTF8String << endl;
    }
}
