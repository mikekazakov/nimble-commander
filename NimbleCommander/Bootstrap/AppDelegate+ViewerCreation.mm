// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppDelegate+ViewerCreation.h"
#include <Viewer/BigFileView.h>
#include <NimbleCommander/Viewer/ThemeAdaptor.h>
#include <Viewer/InternalViewerController.h>
#include <Viewer/History.h>

@implementation NCAppDelegate(ViewerCreation)

- (BigFileView*) makeViewerWithFrame:(NSRect)frame
{
    auto theme_adaptor = std::make_unique<nc::viewer::ThemeAdaptor>(self.themesManager);
    return [[BigFileView alloc] initWithFrame:frame
                                  tempStorage:self.temporaryFileStorage
                                       config:self.globalConfig
                                        theme:std::move(theme_adaptor)];
}

- (InternalViewerController*) makeViewerController
{
    return [[InternalViewerController alloc]
            initWithHistory:self.internalViewerHistory
            config:self.globalConfig];
}

@end