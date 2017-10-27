// Copyright (C) 2013-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

@interface SharingService : NSObject<NSSharingServicePickerDelegate>

- (void) ShowItems:(const vector<string>&)_entries
             InDir:(string)_dir
             InVFS:(shared_ptr<VFSHost>)_host
    RelativeToRect:(NSRect)_rect
            OfView:(NSView*)_view
     PreferredEdge:(NSRectEdge)_preferredEdge;

+ (bool) IsCurrentlySharing; // use this to prohibit parallel sharing - this can cause significal system overload
+ (bool) SharingEnabledForItem:(const VFSListingItem&)_item;

@end
