#pragma once
#import <Cocoa/Cocoa.h>
#include "Options.h"

class VFSListingItem;

@interface NCOpsAttrsChangingDialog : NSWindowController


- (instancetype) initWithItems:(vector<VFSListingItem>)_items;

@property (readonly) const nc::ops::AttrsChangingCommand &command;

@end
