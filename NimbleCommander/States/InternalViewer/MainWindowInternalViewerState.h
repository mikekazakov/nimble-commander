// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include "../MainWindowStateProtocol.h"
#include "../../Viewer/BigFileView.h"
#include "../../Viewer/InternalViewerToolbarProtocol.h"

@interface MainWindowInternalViewerState : NSViewController<NCMainWindowState>

- (bool)openFile:(const std::string&)_path
           atVFS:(const VFSHostPtr&)_host;

@end
