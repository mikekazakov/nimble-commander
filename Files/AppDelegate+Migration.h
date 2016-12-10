#pragma once

#include "../NimbleCommander/Bootstrap/AppDelegate.h"

@interface AppDelegate(Migration)

- (void) migrateViewerHistory_1_1_3_to_1_1_5;

@end
