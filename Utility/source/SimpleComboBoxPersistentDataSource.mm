// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/Utility/SimpleComboBoxPersistentDataSource.h"

@implementation NCUtilSimpleComboBoxPersistentDataSource

- (void)reportEnteredItem:(nullable NSString*)item
{
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox
{
    return 0;
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index
{
    return @"";
}

@end
