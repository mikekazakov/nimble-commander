// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>


@interface PreferencesWindowPanelsTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                            NSTableViewDataSource,
                                                            NSTableViewDelegate,
                                                            NSTextFieldDelegate>

@end
