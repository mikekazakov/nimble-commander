//
//  FileAlreadyExistSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 16.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>
#include "../OperationDialogProtocol.h"

@interface FileAlreadyExistSheetController : SheetController<OperationDialogProtocol>

@property bool allowAppending; // if this is true - "append" button will be enabled
@property bool singleItem; // if this is true - "apply to all will be hidden"
@property shared_ptr<bool> applyToAll;

- (id)initWithDestPath:(const string&)_path
        withSourceStat:(const struct stat &)_src_stat
   withDestinationStat:(const struct stat &)_dst_stat;

@end
