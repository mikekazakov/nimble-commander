// Copyright (C) 2018-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "Actions/DefaultAction.h"
#include <Utility/NativeFSManager.h>
#include <Config/Config.h>
#include <functional>
#include <robin_hood.h>

class NetworkConnectionsManager;
@class NCPanelOpenWithMenuDelegate;
@class NCViewerView;
@class NCViewerViewController;

namespace nc::vfs {
class NativeHost;
}

namespace nc::panel {
class FileOpener;
class TagsStorage;

using PanelActionsMap =
    robin_hood::unordered_flat_map<SEL, std::unique_ptr<const actions::PanelAction>>;

PanelActionsMap
BuildPanelActionsMap(nc::config::Config &_global_config,
                     NetworkConnectionsManager &_net_mgr,
                     nc::utility::NativeFSManager &_native_fs_mgr,
                     nc::vfs::NativeHost &_native_host,
                     const nc::panel::TagsStorage &_tags_storage,
                     FileOpener &_file_opener,
                     NCPanelOpenWithMenuDelegate *_open_with_menu_delegate,
                     std::function<NCViewerView *(NSRect)> _make_viewer,
                     std::function<NCViewerViewController *()> _make_viewer_controller);

}
