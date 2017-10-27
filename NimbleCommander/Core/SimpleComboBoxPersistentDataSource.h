// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SimpleComboBoxPersistentDataSource.h>

@interface SimpleComboBoxPersistentDataSource : NCUtilSimpleComboBoxPersistentDataSource

- (instancetype)initWithStateConfigPath:(const string&)path;

- (void)reportEnteredItem:(NSString*)item; // item can be nil

@end
