// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
#include "Options.h"

@interface NCOpsAttrsChangingDialog : NSWindowController

- (instancetype)initWithItems:(std::vector<VFSListingItem>)_items;

+ (bool)canEditAnythingInItems:(const std::vector<VFSListingItem> &)_items;

@property(readonly, nonatomic) const nc::ops::AttrsChangingCommand &command;

@end
