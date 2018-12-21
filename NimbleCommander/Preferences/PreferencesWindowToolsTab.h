// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>
#include <functional>

class ExternalToolsStorage;

@interface PreferencesWindowToolsTab : NSViewController<RHPreferencesViewControllerProtocol,
                                                        NSTableViewDataSource,
                                                        NSTableViewDelegate>

- (id) initWithToolsStorage:(std::function<ExternalToolsStorage&()>)_tool_storage;

@end
