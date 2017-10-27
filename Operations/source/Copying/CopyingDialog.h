// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#include <VFS/VFS.h>
#include "Options.h"

@interface NCOpsCopyingDialog : NSWindowController<NSTextFieldDelegate>

@property (readonly) string                     resultDestination;
@property (readonly) VFSHostPtr                 resultHost;
@property (readonly) nc::ops::CopyingOptions    resultOptions;
@property bool allowVerification;

- (instancetype) initWithItems:(vector<VFSListingItem>)_source_items
                     sourceVFS:(const VFSHostPtr&)_source_host
               sourceDirectory:(const string&)_source_directory
            initialDestination:(const string&)_initial_destination
                destinationVFS:(const VFSHostPtr&)_destination_host
              operationOptions:(const nc::ops::CopyingOptions&)_options;

@end
