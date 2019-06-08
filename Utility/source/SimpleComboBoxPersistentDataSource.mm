// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "../include/Utility/SimpleComboBoxPersistentDataSource.h"

@implementation NCUtilSimpleComboBoxPersistentDataSource

- (void)reportEnteredItem:(nullable NSString*) [[maybe_unused]] item
{
}

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *) [[maybe_unused]] aComboBox
{
    return 0;
}

- (id)comboBox:(NSComboBox *) [[maybe_unused]] aComboBox
objectValueForItemAtIndex:(NSInteger) [[maybe_unused]] index
{
    return @"";
}

@end
