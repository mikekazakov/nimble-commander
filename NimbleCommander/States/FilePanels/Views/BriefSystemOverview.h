// Copyright (C) 2013-2019 Michael Kazakov. Subject to GNU General Public License version 3.

#pragma once

#include <VFS/VFS.h>
#include <Cocoa/Cocoa.h>

@interface BriefSystemOverview : NSView

- (void) UpdateVFSTarget:(const std::string&)_path host:(std::shared_ptr<VFSHost>)_host;

@end
