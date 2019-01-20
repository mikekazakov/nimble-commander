// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppDelegate+ViewerCreation.h"
#include <NimbleCommander/Viewer/BigFileView.h>

@implementation NCAppDelegate(ViewerCreation)

- (BigFileView*) makeViewerWithFrame:(NSRect)frame
{
    return [[BigFileView alloc] initWithFrame:frame
                                  tempStorage:self.temporaryFileStorage
                                       config:self.globalConfig];
}

@end
