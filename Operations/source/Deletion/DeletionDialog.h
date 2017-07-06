#pragma once

#include <Cocoa/Cocoa.h>
//#include <Utility/SheetController.h>
#include "Options.h"

class VFSListingItem;

@interface NCOpsDeletionDialog : NSWindowController

@property (nonatomic)           bool                  allowMoveToTrash;
@property (nonatomic)           nc::ops::DeletionType defaultType;
@property (nonatomic, readonly) nc::ops::DeletionType resultType;

- (id)initWithItems:(const shared_ptr<vector<VFSListingItem>>&)_items;

@end
