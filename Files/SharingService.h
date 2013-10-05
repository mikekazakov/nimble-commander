//
//  SharingService.h
//  Files
//
//  Created by Michael G. Kazakov on 04.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FlexChainedStringsChunk.h"
#import "VFS.h"
@interface SharingService : NSObject<NSSharingServicePickerDelegate>

- (void) ShowItems:(FlexChainedStringsChunk*)_entries
             InDir:(const char*)_dir
             InVFS:(std::shared_ptr<VFSHost>)_host
    RelativeToRect:(NSRect)_rect
            OfView:(NSView*)_view
     PreferredEdge:(NSRectEdge)_preferredEdge;

+ (uint64_t) MaximumFileSizeForVFSShare;
+ (bool) IsCurrentlySharing; // use this to prohibit parallel sharing - this can cause significal system overload

@end
