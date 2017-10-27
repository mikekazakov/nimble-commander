// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>

@interface PreferencesWindowThemesTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                          NSOutlineViewDelegate,
                                                          NSOutlineViewDataSource,
                                                          NSTextFieldDelegate>

@end
