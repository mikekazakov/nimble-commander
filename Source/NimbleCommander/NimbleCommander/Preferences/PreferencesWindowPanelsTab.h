// Copyright (C) 2013-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#import <RHPreferences/RHPreferences.h>

@interface PreferencesWindowPanelsTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                          NSTableViewDataSource,
                                                          NSTableViewDelegate,
                                                          NSTextFieldDelegate>

@end
