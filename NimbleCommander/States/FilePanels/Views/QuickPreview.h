//
//  QuickPreview.h
//  Files
//
//  Created by Pavel Dogurevich on 26.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFS.h>

@interface QuickLookView : NSView

- (void)PreviewItem:(const string&)_path vfs:(const VFSHostPtr&)_host;

@end
