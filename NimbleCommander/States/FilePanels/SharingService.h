// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Cocoa/Cocoa.h>

@interface SharingService : NSObject<NSSharingServicePickerDelegate>

- (void) ShowItems:(const std::vector<std::string>&)_entries
             InDir:(std::string)_dir
             InVFS:(std::shared_ptr<VFSHost>)_host
    RelativeToRect:(NSRect)_rect
            OfView:(NSView*)_view
     PreferredEdge:(NSRectEdge)_preferredEdge;

+ (bool) IsCurrentlySharing; // use this to prohibit parallel sharing - this can cause significal system overload
+ (bool) SharingEnabledForItem:(const VFSListingItem&)_item;

@end
