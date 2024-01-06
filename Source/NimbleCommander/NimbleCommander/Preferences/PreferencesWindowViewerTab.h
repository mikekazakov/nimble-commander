// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#import <RHPreferences/RHPreferences/RHPreferences.h>

namespace nc::viewer {
class History;
}
namespace nc::bootstrap {
class ActivationManager;
}

@interface PreferencesWindowViewerTab : NSViewController <RHPreferencesViewControllerProtocol>

- (id)init NS_UNAVAILABLE;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithHistory:(nc::viewer::History &)_history
              activationManager:(nc::bootstrap::ActivationManager &)_am;

@end
