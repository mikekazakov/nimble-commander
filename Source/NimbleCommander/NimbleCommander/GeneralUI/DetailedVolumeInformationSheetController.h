// Copyright (C) 2013-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <string>

namespace nc::utility {
class NativeFSManager;
}

@interface DetailedVolumeInformationSheetController : SheetController

- (instancetype)initWithFSManager:(nc::utility::NativeFSManager &)_native_fs_manager;

- (void)showSheetForWindow:(NSWindow *)_window withPath:(const std::string &)_path;

@end
