#pragma once
#import <Cocoa/Cocoa.h>

class VFSListingItem;

#include "Options.h"

@interface NCOpsAttrsChangingDialog : NSWindowController


- (instancetype) initWithItems:(vector<VFSListingItem>)_items;

@property (readonly) const nc::ops::AttrsChangingCommand &command;

@end
