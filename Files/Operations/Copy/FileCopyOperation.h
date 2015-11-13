//
//  FileCopyOperation.h
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "../../vfs/VFS.h"
#include "../Operation.h"
#include "Options.h"

@interface FileCopyOperation : Operation

- (id)initWithItems:(vector<VFSListingItem>)_files
    destinationPath:(const string&)_path
    destinationHost:(const VFSHostPtr&)_host
            options:(const FileCopyOperationOptions&)_options;

+ (instancetype) singleItemRenameOperation:(VFSListingItem)_item
                                   newName:(const string&)_filename;

- (void)Update;

@end
