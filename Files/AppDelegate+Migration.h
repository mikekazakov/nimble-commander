#pragma once

#include "AppDelegate.h"

@interface AppDelegate(Migration)

- (void) migrateUserDefaultsToJSONConfig_1_1_0_to_1_1_1;

@end
