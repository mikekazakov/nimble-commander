//
//  BatchRenameSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 16/05/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>
#include "../../vfs/VFS.h"

@interface BatchRenameSheetController : SheetController<NSTableViewDataSource,NSTableViewDelegate,NSTextFieldDelegate,NSComboBoxDelegate>

@property (readonly) vector<string> &filenamesSource;       // full path
@property (readonly) vector<string> &filenamesDestination;
@property bool isValidRenaming;

- (instancetype) initWithItems:(vector<VFSListingItem>)_items;

@end
