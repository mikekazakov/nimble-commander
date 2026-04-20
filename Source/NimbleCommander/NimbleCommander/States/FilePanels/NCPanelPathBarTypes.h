#pragma once

#import <Cocoa/Cocoa.h>

#include <functional>
#include <optional>
#include <string>
#include <vector>

namespace nc::panel {

struct PanelHeaderBreadcrumb {
    NSString *_Nullable label = nil;
    std::optional<std::string> navigate_to_vfs_path;
    bool is_current_directory = false;
};

struct PanelPathContext {
    std::string verbose_full_path;
    std::string directory_path;
    std::string posix_path;
};

enum class NCPanelPathBarContextCommand : int {
    Open = 0,
    OpenInNewTab,
    CopyPath,
};

using NCPanelPathBarContextMenuAction = std::function<void(NSString *_Nonnull posixPath,
                                                           NCPanelPathBarContextCommand command)>;

} // namespace nc::panel
