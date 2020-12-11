// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <3rd_Party/RHPreferences/RHPreferences/RHPreferences.h>

namespace nc::bootstrap {
class ActivationManager;
}

@interface PreferencesWindowThemesTab : NSViewController <RHPreferencesViewControllerProtocol,
                                                          NSOutlineViewDelegate,
                                                          NSOutlineViewDataSource,
                                                          NSTextFieldDelegate>

- (instancetype)initWithActivationManager:(nc::bootstrap::ActivationManager &)_am;

@end
