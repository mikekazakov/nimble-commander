// Copyright (C) 2016-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#import <RHPreferences/RHPreferences.h>
#include <functional>

namespace nc::panel {
class ExternalToolsStorage;
}

@interface PreferencesWindowToolsTab
    : NSViewController <RHPreferencesViewControllerProtocol, NSTableViewDataSource, NSTableViewDelegate>

- (id)initWithToolsStorage:(std::function<nc::panel::ExternalToolsStorage &()>)_tool_storage;

@end
