// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <RHPreferences/RHPreferences/RHPreferences.h>

@interface PreferencesWindowThemesTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                          NSOutlineViewDelegate,
                                                          NSOutlineViewDataSource,
                                                          NSTextFieldDelegate,
                                                          NSTableViewDataSource,
                                                          NSTableViewDelegate,
                                                          NSMenuItemValidation>

@end
