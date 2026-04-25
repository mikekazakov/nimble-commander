#pragma once

#include <Panel/PathBar.h>

#include <functional>

namespace nc::panel {

// UI-level commands triggered from the path bar context menu.
enum class NCPanelPathBarContextCommand : int {
    Open = 0,
    OpenInNewTab,
    CopyPath,
};

using NCPanelPathBarContextMenuAction = std::function<void(NSString *_Nonnull posixPath,
                                                           NCPanelPathBarContextCommand command)>;

} // namespace nc::panel
