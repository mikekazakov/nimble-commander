// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

@interface QuickLookView : NSView

- (void)PreviewItem:(const string&)_path vfs:(const VFSHostPtr&)_host;

@end
