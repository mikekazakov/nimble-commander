// Copyright (C) 2015-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SimpleComboBoxPersistentDataSource.h>
#include <string>

@interface SimpleComboBoxPersistentDataSource : NCUtilSimpleComboBoxPersistentDataSource

- (instancetype)initWithStateConfigPath:(const std::string &)path;

- (void)reportEnteredItem:(NSString *)item; // item can be nil

@end
