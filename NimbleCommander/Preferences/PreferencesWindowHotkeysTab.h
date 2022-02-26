// Copyright (C) 2014-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>
#include <functional>

namespace nc::panel {
class ExternalToolsStorage;
}

namespace nc::bootstrap {
class ActivationManager;
}

@interface PreferencesWindowHotkeysTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                           NSTableViewDataSource,
                                                           NSTableViewDelegate,
                                                           NSTextFieldDelegate>

- (id)initWithToolsStorage:(std::function<nc::panel::ExternalToolsStorage &()>)_tool_storage
         activationManager:(nc::bootstrap::ActivationManager &)_am;

@end
