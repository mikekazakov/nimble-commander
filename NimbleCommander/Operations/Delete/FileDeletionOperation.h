//
//  FileDeletionOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFS.h>
#include <NimbleCommander/Operations/Operation.h>
#include "Options.h"

@class OperationDialogAlert;

@interface FileDeletionOperation : Operation


- (id)initWithFiles:(vector<VFSListingItem>)_files
               type:(FileDeletionOperationType)_type; // "trash" is supported only on native fs. will throw otherwise


- (OperationDialogAlert *)DialogOnOpendirError:(NSError*)_error ForDir:(const char *)_path;
- (OperationDialogAlert *)DialogOnUnlinkError:(NSError*)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnRmdirError:(NSError*)_error ForPath:(const char *)_path;
- (OperationDialogAlert *)DialogOnTrashItemError:(NSError *)_error ForPath:(const char *)_path;
@end
