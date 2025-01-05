// Copyright (C) 2019-2024 Michael Kazakov. Subject to GNU General Public License version 3.
#include "AppDelegate+ViewerCreation.h"
#include <Viewer/ViewerView.h>
#include <NimbleCommander/Viewer/ThemeAdaptor.h>
#include <NimbleCommander/Core/ActionsShortcutsManager.h>
#include <Viewer/ViewerViewController.h>
#include <Viewer/History.h>

@implementation NCAppDelegate (ViewerCreation)

- (NCViewerView *)makeViewerWithFrame:(NSRect)frame
{
    auto theme_adaptor = std::make_unique<nc::viewer::ThemeAdaptor>(self.themesManager);
    return [[NCViewerView alloc] initWithFrame:frame
                                   tempStorage:self.temporaryFileStorage
                                        config:self.globalConfig
                                         theme:std::move(theme_adaptor)
                          highlightingSettings:self.syntaxHighlightingSettingsStorage];
}

- (NCViewerViewController *)makeViewerController
{
    return [[NCViewerViewController alloc] initWithHistory:self.internalViewerHistory
                                                    config:self.globalConfig
                                                 shortcuts:self.actionsShortcutsManager];
}

@end
