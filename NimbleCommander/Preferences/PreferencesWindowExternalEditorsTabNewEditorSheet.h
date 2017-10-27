// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <NimbleCommander/States/FilePanels/ExternalEditorInfo.h>
#include <NimbleCommander/States/FilePanels/ExternalEditorInfoPrivate.h>

@interface PreferencesWindowExternalEditorsTabNewEditorSheet : SheetController

@property (nonatomic, strong) ExternalEditorInfo *Info;
@property (nonatomic, readonly) bool hasTerminal;

- (IBAction)OnClose:(id)sender;
- (IBAction)OnOK:(id)sender;
- (IBAction)OnChoosePath:(id)sender;

@end
