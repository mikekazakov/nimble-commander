// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ToolsMenuDelegate.h"
#include <NimbleCommander/Bootstrap/AppDelegate.h>
#include <NimbleCommander/Core/AnyHolder.h>
#include "MainWindowFilePanelState.h"
#include "StateActionsDispatcher.h"
#include <Utility/StringExtras.h>
#include <Utility/ObjCpp.h>
#include <Panel/ExternalTools.h>

static NSMenuItem *ItemForTool(const std::shared_ptr<const nc::panel::ExternalTool> &_tool, int _ind)
{
    NSMenuItem *const item = [[NSMenuItem alloc] init];
    item.title = _tool->m_Title.empty() ? [NSString stringWithFormat:NSLocalizedString(@"Tool #%u", ""), _ind]
                                        : [NSString stringWithUTF8StdString:_tool->m_Title];
    item.representedObject = [[AnyHolder alloc] initWithAny:std::any{_tool}];
    if( !_tool->m_ExecutablePath.empty() )
        item.action = @selector(onExecuteExternalTool:);
    else
        item.action = nil;
    item.keyEquivalent = _tool->m_Shorcut.Key();
    item.keyEquivalentModifierMask = _tool->m_Shorcut.modifiers;
    return item;
}

@implementation ToolsMenuDelegate {
    bool m_IsDirty;
    nc::panel::ExternalToolsStorage::ObservationTicket m_ToolsObserver;
    __weak NSMenu *m_MyMenu;
}

- (id)init
{
    self = [super init];
    if( self ) {
        m_IsDirty = true;
    }
    return self;
}

- (void)toolsHaveChanged
{
    m_IsDirty = true;
    dispatch_or_run_in_main_queue([=] { [self menuNeedsUpdate:m_MyMenu]; });
}

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    // this delegate need to trigger update of the menu later, so will store the pointer
    if( !m_MyMenu )
        m_MyMenu = menu;

    // deferred observer setup
    if( !m_ToolsObserver )
        m_ToolsObserver =
            NCAppDelegate.me.externalTools.ObserveChanges(nc::objc_callback(self, @selector(toolsHaveChanged)));

    if( m_IsDirty ) {
        const auto tools = NCAppDelegate.me.externalTools.GetAllTools();

        [menu removeAllItems];
        for( int i = 0, e = static_cast<int>(tools.size()); i != e; ++i )
            [menu addItem:ItemForTool(tools[i], i)];

        m_IsDirty = false;
    }
}

@end
