// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFS.h>
#include "Options.h"

@interface NCOpsCopyingDialog : NSWindowController<NSTextFieldDelegate>

@property (readonly, nonatomic) std::string                resultDestination;
@property (readonly, nonatomic) VFSHostPtr                 resultHost;
@property (readonly, nonatomic) nc::ops::CopyingOptions    resultOptions;
@property (nonatomic) bool allowVerification; // no-lic - remove me

- (instancetype) initWithItems:(std::vector<VFSListingItem>)_source_items
                     sourceVFS:(const VFSHostPtr&)_source_host
               sourceDirectory:(const std::string&)_source_directory
            initialDestination:(const std::string&)_initial_destination
                destinationVFS:(const VFSHostPtr&)_destination_host
              operationOptions:(const nc::ops::CopyingOptions&)_options;

@end
