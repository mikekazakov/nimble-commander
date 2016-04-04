//
//  MassCopySheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Utility/SheetController.h>
#include "../../vfs/VFS.h"

struct FileCopyOperationOptions;

@interface MassCopySheetController : SheetController<NSTextFieldDelegate>

@property (readonly) string                     resultDestination;
@property (readonly) VFSHostPtr                 resultHost;
@property (readonly) FileCopyOperationOptions   resultOptions;

- (instancetype) initWithItems:(vector<VFSListingItem>)_source_items
                     sourceVFS:(const VFSHostPtr&)_source_host
               sourceDirectory:(const string&)_source_directory
            initialDestination:(const string&)_initial_destination
                destinationVFS:(const VFSHostPtr&)_destination_host
              operationOptions:(const FileCopyOperationOptions&)_options;

@end
