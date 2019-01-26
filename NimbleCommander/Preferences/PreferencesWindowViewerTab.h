// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>

namespace nc::viewer {
    class History;
}

@interface PreferencesWindowViewerTab : NSViewController <RHPreferencesViewControllerProtocol>

- (id)init NS_UNAVAILABLE;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (instancetype)initWithHistory:(nc::viewer::History&)_history;

@end
