//
//  CreateDirectoryOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "Operation.h"
#include "OperationDialogAlert.h"
#include "vfs/VFS.h"

@interface CreateDirectoryOperation : Operation

- (id)initWithPath:(const char*)_path rootpath:(const char*)_rootpath;
- (id)initWithPath:(const char*)_path rootpath:(const char*)_rootpath at:(const VFSHostPtr&)_host;

- (OperationDialogAlert *)dialogOnDirCreationFailed:(NSError*)_error forDir:(const char *)_path;

@end
