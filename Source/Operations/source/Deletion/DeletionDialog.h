// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
#include "Options.h"

@interface NCOpsDeletionDialog : NSWindowController

@property (nonatomic)           bool                  allowMoveToTrash;
@property (nonatomic)           nc::ops::DeletionType defaultType;
@property (nonatomic, readonly) nc::ops::DeletionType resultType;

- (id)initWithItems:(const std::shared_ptr<std::vector<VFSListingItem>>&)_items;

@end
