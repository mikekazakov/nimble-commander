//
//  SharingService.h
//  Files
//
//  Created by Michael G. Kazakov on 04.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "vfs/VFS.h"

@interface SharingService : NSObject<NSSharingServicePickerDelegate>

- (void) ShowItems:(const vector<string>&)_entries
             InDir:(string)_dir
             InVFS:(shared_ptr<VFSHost>)_host
    RelativeToRect:(NSRect)_rect
            OfView:(NSView*)_view
     PreferredEdge:(NSRectEdge)_preferredEdge;

+ (bool) IsCurrentlySharing; // use this to prohibit parallel sharing - this can cause significal system overload
+ (bool) SharingEnabledForItem:(const VFSFListingItem&)_item;

@end
