// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "ViewerView.h"

#include <functional>
#include <string>

namespace nc::config {
class Config;
}
namespace nc::viewer {
class History;
};
namespace nc::utility {
struct ActionShortcut;
class ActionsShortcutsManager;
} // namespace nc::utility

@interface NCViewerViewController : NSResponder <NSSearchFieldDelegate, NSPopoverDelegate>

// UI wiring
@property(nonatomic) NCViewerView *view;

// Useful information
@property(nonatomic, readonly) NSString *verboseTitle;
@property(nonatomic, readonly) const std::string &filePath;
@property(nonatomic, readonly) const VFSHostPtr &fileVFS;

@property(nonatomic, readonly) bool isOpened;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithHistory:(nc::viewer::History &)_history
                         config:(nc::config::Config &)_config
                      shortcuts:(const nc::utility::ActionsShortcutsManager &)_shortcuts;

- (void)setFile:(std::string)path at:(VFSHostPtr)vfs;

- (bool)performBackgroundOpening;

- (void)show;
- (void)clear;
- (void)saveFileState;

- (void)markSelection:(CFRange)_selection forSearchTerm:(std::string)_request;

@end
