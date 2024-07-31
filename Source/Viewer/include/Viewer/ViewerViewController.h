// Copyright (C) 2016-2021 Michael Kazakov. Subject to GNU General Public License version 3.
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
}

@interface NCViewerViewController : NSResponder <NSSearchFieldDelegate, NSPopoverDelegate>

// UI wiring
@property(nonatomic) NCViewerView *view;
@property(nonatomic) NSSearchField *searchField;
@property(nonatomic) NSProgressIndicator *searchProgressIndicator;
@property(nonatomic) NSPopUpButton *encodingsPopUp;
@property(nonatomic) NSButton *positionButton;
@property(nonatomic) NSButton *wordWrappingCheckBox;
@property(nonatomic) NSButton *settingsButton;

// Useful information
@property(nonatomic, readonly) NSString *verboseTitle;
@property(nonatomic, readonly) const std::string &filePath;
@property(nonatomic, readonly) const VFSHostPtr &fileVFS;

@property(nonatomic, readonly) bool isOpened;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithHistory:(nc::viewer::History &)_history
                         config:(nc::config::Config &)_config
              shortcutsProvider:(std::function<nc::utility::ActionShortcut(std::string_view _name)>)_shortcuts;

- (void)setFile:(std::string)path at:(VFSHostPtr)vfs;

- (bool)performBackgroundOpening;

- (void)show;
- (void)clear;
- (void)saveFileState;

- (void)markSelection:(CFRange)_selection forSearchTerm:(std::string)_request;

@end
