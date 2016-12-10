#include "3rd_party/NSFileManager+DirectoryLocations.h"
#include "../NimbleCommander/Bootstrap/Config.h"
#include "AppDelegate+Migration.h"

#include "../NimbleCommander/Viewer/BigFileViewHistory.h"

@implementation AppDelegate (Migration)

- (void) migrateViewerHistory_1_1_3_to_1_1_5
{
    [BigFileViewHistory moveToNewHistory];
}

@end
