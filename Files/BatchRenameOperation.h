//
//  BatchRenameOperation.h
//  Files
//
//  Created by Michael G. Kazakov on 11/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "VFS.h"
#import "Operation.h"

@interface BatchRenameOperation : Operation

- (id)initWithOriginalFilepaths:(vector<string>&&)_src_paths
               renamedFilepaths:(vector<string>&&)_dst_paths
                            vfs:(VFSHostPtr)_src_vfs;

@end
