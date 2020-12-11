// Copyright (C) 2018-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Actions/DefaultAction.h"
#include <Utility/NativeFSManager.h>
#include <Config/Config.h>
#include <unordered_map>

class NetworkConnectionsManager;
@class NCPanelOpenWithMenuDelegate;
@class NCViewerView;
@class NCViewerViewController;

namespace nc::bootstrap {
class ActivationManager;
}

namespace nc::vfs {
class NativeHost;
}

namespace nc::panel {
class FileOpener;

using PanelActionsMap = std::unordered_map<SEL, std::unique_ptr<const actions::PanelAction>>;

PanelActionsMap
BuildPanelActionsMap(nc::config::Config &_global_config,
                     NetworkConnectionsManager &_net_mgr,
                     nc::utility::NativeFSManager &_native_fs_mgr,
                     nc::bootstrap::ActivationManager &_activation_manager,
                     nc::vfs::NativeHost &_native_host,
                     FileOpener &_file_opener,
                     NCPanelOpenWithMenuDelegate *_open_with_menu_delegate,
                     std::function<NCViewerView *(NSRect)> _make_viewer,
                     std::function<NCViewerViewController *()> _make_viewer_controller);

}
