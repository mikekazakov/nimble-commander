// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#import <RHPreferences/RHPreferences.h>
#include <functional>

namespace nc::panel {
class ExternalToolsStorage;
}

@interface PreferencesWindowHotkeysTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                           NSTableViewDataSource,
                                                           NSTableViewDelegate,
                                                           NSTextFieldDelegate>

- (id)initWithToolsStorage:(std::function<nc::panel::ExternalToolsStorage &()>)_tool_storage;

@end
