//
//  BatchRenameOperation.h
//  Files
//
//  Created by Michael G. Kazakov on 11/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFS.h>
#include <NimbleCommander/Operations/Operation.h>
#include <NimbleCommander/Operations/OperationDialogAlert.h>

@interface BatchRenameOperation : Operation

- (instancetype)initWithOriginalFilepaths:(vector<string>&&)_src_paths
                         renamedFilepaths:(vector<string>&&)_dst_paths
                                      vfs:(VFSHostPtr)_src_vfs;

- (OperationDialogAlert *)DialogOnRenameError:(NSError*)_error source:(const string&)_source destination:(const string&)_destination;

@end
