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
