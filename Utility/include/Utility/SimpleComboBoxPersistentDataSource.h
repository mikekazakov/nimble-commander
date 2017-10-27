// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCUtilSimpleComboBoxPersistentDataSource : NSObject<NSComboBoxDataSource>

- (void)reportEnteredItem:(nullable NSString*)item;

@end
