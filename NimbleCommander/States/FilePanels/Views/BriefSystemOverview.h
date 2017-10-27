// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

#include <VFS/VFS.h>

@interface BriefSystemOverview : NSView

- (void) UpdateVFSTarget:(const string&)_path host:(shared_ptr<VFSHost>)_host;

@end
