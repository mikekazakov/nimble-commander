// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SimpleComboBoxPersistentDataSource.h>

@interface SimpleComboBoxPersistentDataSource : NCUtilSimpleComboBoxPersistentDataSource

- (instancetype)initWithStateConfigPath:(const std::string&)path;

- (void)reportEnteredItem:(NSString*)item; // item can be nil

@end
