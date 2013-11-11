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
#import "OperationDialogAlert.h"

@interface FileCompressOperation : Operation

- (id)initWithFiles:(FlexChainedStringsChunk*)_src_files // passing with ownership, operation will free it on finish
            srcroot:(const char*)_src_root
             srcvfs:(std::shared_ptr<VFSHost>)_src_vfs
            dstroot:(const char*)_dst_root
             dstvfs:(std::shared_ptr<VFSHost>)_dst_vfs;


- (OperationDialogAlert *)OnCantAccessSourceItem:(NSError*)_error forPath:(const char *)_path;
- (OperationDialogAlert *)OnCantAccessSourceDir:(NSError*)_error forPath:(const char *)_path;
- (OperationDialogAlert *)OnReadError:(NSError*)_error forPath:(const char *)_path;
- (OperationDialogAlert *)OnWriteError:(NSError*)_error;
- (void) SayAbout4Gb:(const char*) _path;
@end
