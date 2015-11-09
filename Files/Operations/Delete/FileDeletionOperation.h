//
//  FileDeletionOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../../Operation.h"
#include "../../vfs/VFS.h"
#include "Options.h"

@class OperationDialogAlert;

@interface FileDeletionOperation : Operation


- (id)initWithFiles:(vector<VFSListingItem>)_files
               type:(FileDeletionOperationType)_type; // "trash" and "secure delete" are supported only on native fs. will throw otherwise


//- (id)initWithFiles:(vector<string>&&)_files
//               type:(FileDeletionOperationType)_type
//                dir:(const string&)_path;
//
//// VFS deletion can be only "delete", not "moving to trash" or "secure delete"
//- (id)initWithFiles:(vector<string>&&)_files
//                dir:(const string&)_path
//                 at:(const VFSHostPtr&) _host;

- (void)Update;

- (OperationDialogAlert *)DialogOnOpendirError:(NSError*)_error ForDir:(const char *)_path;
- (OperationDialogAlert *)DialogOnUnlinkError:(NSError*)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnRmdirError:(NSError*)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnTrashItemError:(NSError *)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnSecureRewriteError:(NSError *)_error ForPath:(const char *)_path;
@end
