//
//  FileSysEntryAttrSheetController.h
//  Directories
//
//  Created by Michael G. Kazakov on 26.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>
#include <VFS/VFS.h>

struct FileSysAttrAlterCommand;

@interface FileSysEntryAttrSheetController : SheetController

@property (nonatomic, readonly) shared_ptr<FileSysAttrAlterCommand> result;

- (FileSysEntryAttrSheetController*)initWithItems:(const shared_ptr<const vector<VFSListingItem>>&)_items;

@end
