// Copyright (C) 2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>

@interface NCOpsCompressDialog : NSWindowController<NSTextFieldDelegate>

- (instancetype) initWithItems:(const std::vector<VFSListingItem>&)_source_items
                destinationVFS:(const VFSHostPtr&)_destination_host
            initialDestination:(const std::string&)_initial_destination;

@property (readonly, nonatomic) const std::string &destination;
@property (readonly, nonatomic) const std::string &password;

@end
