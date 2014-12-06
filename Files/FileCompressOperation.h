//
//  FileCompressOperation.h
//  Files
//
//  Created by Michael G. Kazakov on 21.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFS.h"
#import "Operation.h"
#import "OperationDialogAlert.h"

@interface FileCompressOperation : Operation

- (id)initWithFiles:(vector<string>&&)_src_files
            srcroot:(const string&)_src_root
             srcvfs:(VFSHostPtr)_src_vfs
            dstroot:(const string&)_dst_root
             dstvfs:(VFSHostPtr)_dst_vfs;


- (OperationDialogAlert *)OnCantAccessSourceItem:(NSError*)_error forPath:(const char *)_path;
- (OperationDialogAlert *)OnCantAccessSourceDir:(NSError*)_error forPath:(const char *)_path;
- (OperationDialogAlert *)OnReadError:(NSError*)_error forPath:(const char *)_path;
- (OperationDialogAlert *)OnWriteError:(NSError*)_error;
- (void) SayAbout4Gb:(const char*) _path;
@end
