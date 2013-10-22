//
//  FileCompressOperation.h
//  Files
//
//  Created by Michael G. Kazakov on 21.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "FlexChainedStringsChunk.h"
#import "VFS.h"
#import "Operation.h"

@interface FileCompressOperation : Operation

- (id)initWithFiles:(FlexChainedStringsChunk*)_src_files // passing with ownership, operation will free it on finish
            srcroot:(const char*)_src_root
             srcvfs:(std::shared_ptr<VFSHost>)_src_vfs
            dstroot:(const char*)_dst_root
             dstvfs:(std::shared_ptr<VFSHost>)_dst_vfs;


@end
