// Copyright (C) 2013-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>

@interface DetailedVolumeInformationSheetController : SheetController

- (void)showSheetForWindow:(NSWindow *)_window withPath:(const string&)_path;

@end
