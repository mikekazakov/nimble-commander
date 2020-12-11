// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>

namespace nc::bootstrap {
class ActivationManager;
}

@interface PreferencesWindowTerminalTab : NSViewController<RHPreferencesViewControllerProtocol>

- (instancetype)initWithActivationManager:(nc::bootstrap::ActivationManager &)_am;

@end
