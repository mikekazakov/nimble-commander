// Copyright (C) 2017-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <Cocoa/Cocoa.h>
#include <swiftToCxx/_SwiftCxxInteroperability.h>
#include <NimbleCommanderCommon-Swift.h>

@interface PreferencesWindowThemesTab : NSViewController <PreferencesViewControllerProtocol,
                                                          NSOutlineViewDelegate,
                                                          NSOutlineViewDataSource,
                                                          NSTextFieldDelegate,
                                                          NSTableViewDataSource,
                                                          NSTableViewDelegate,
                                                          NSMenuItemValidation>

@end
