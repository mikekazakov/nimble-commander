//
//  FileDeletionSheetWindowController.h
//  Directories
//
//  Created by Pavel Dogurevich on 15.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include <Utility/SheetController.h>
#include "FileDeletionOperation.h"

@interface FileDeletionSheetController : SheetController

@property (nonatomic)           bool                      allowMoveToTrash;
@property (nonatomic)           FileDeletionOperationType defaultType;
@property (nonatomic, readonly) FileDeletionOperationType resultType;

- (id)initWithItems:(const shared_ptr<vector<VFSListingItem>>&)_items;

@end
