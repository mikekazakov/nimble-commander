// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>
#include <functional>

namespace nc::panel {
class ExternalToolsStorage;
}

namespace nc::bootstrap {
class ActivationManager;
}

@interface PreferencesWindowToolsTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                         NSTableViewDataSource,
                                                         NSTableViewDelegate>

- (id)initWithToolsStorage:(std::function<nc::panel::ExternalToolsStorage &()>)_tool_storage
         activationManager:(nc::bootstrap::ActivationManager &)_am;

@end
