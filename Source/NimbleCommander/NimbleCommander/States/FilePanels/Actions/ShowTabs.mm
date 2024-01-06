// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "ShowTabs.h"
#include <NimbleCommander/Bootstrap/Config.h>

namespace nc::panel::actions {

static const auto g_ConfigGeneralShowTabs = "general.showTabs";
static const auto g_ShowTitle =
    NSLocalizedString(@"Show Tab Bar", "Menu item title for showing tab bar");
static const auto g_HideTitle =
    NSLocalizedString(@"Hide Tab Bar", "Menu item title for hiding tab bar");

bool ShowTabs::ValidateMenuItem( MainWindowFilePanelState *_target, NSMenuItem *_item ) const
{
    _item.title = GlobalConfig().GetBool(g_ConfigGeneralShowTabs) ?
        g_HideTitle :
        g_ShowTitle;
    return Predicate(_target);
}

void ShowTabs::Perform( [[maybe_unused]] MainWindowFilePanelState *_target, id ) const
{
    const auto shown = GlobalConfig().GetBool(g_ConfigGeneralShowTabs);
    GlobalConfig().Set( g_ConfigGeneralShowTabs, !shown );
}

}
