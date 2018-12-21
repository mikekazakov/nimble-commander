// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <string>

@interface DetailedVolumeInformationSheetController : SheetController

- (void)showSheetForWindow:(NSWindow *)_window
                  withPath:(const std::string&)_path;

@end
