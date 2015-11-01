//
//  BriefSystemOverview.h
//  Files
//
//  Created by Michael G. Kazakov on 08.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "vfs/VFS.h"

@interface BriefSystemOverview : NSView

- (void) UpdateVFSTarget:(const string&)_path host:(shared_ptr<VFSHost>)_host;

@end
