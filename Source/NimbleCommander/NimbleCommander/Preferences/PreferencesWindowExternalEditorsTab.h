// Copyright (C) 2014-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#import <RHPreferences/RHPreferences/RHPreferences.h>

class ExternalEditorsStorage;

namespace nc::bootstrap {
class ActivationManager;
}

@interface PreferencesWindowExternalEditorsTab
    : NSViewController <RHPreferencesViewControllerProtocol, NSTableViewDataSource>

- (instancetype)initWithActivationManager:(nc::bootstrap::ActivationManager &)_am
                           editorsStorage:(ExternalEditorsStorage &)_storage;

@end
