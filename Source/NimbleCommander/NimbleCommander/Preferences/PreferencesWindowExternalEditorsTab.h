// Copyright (C) 2014-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#import <RHPreferences/RHPreferences.h>

class ExternalEditorsStorage;

@interface PreferencesWindowExternalEditorsTab
    : NSViewController <RHPreferencesViewControllerProtocol, NSTableViewDataSource>

- (instancetype)initWithEditorsStorage:(ExternalEditorsStorage &)_storage;

@end
