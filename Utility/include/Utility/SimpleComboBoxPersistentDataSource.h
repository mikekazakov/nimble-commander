#pragma once

#include <Cocoa/Cocoa.h>

@interface NCUtilSimpleComboBoxPersistentDataSource : NSObject<NSComboBoxDataSource>

- (void)reportEnteredItem:(nullable NSString*)item;

@end
