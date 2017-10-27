// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include "../AsyncDialogResponse.h"

@interface NCOpsFileAlreadyExistDialog : NSWindowController

@property bool allowAppending; // if this is true - "append" button will be enabled
@property bool singleItem; // if this is true - "apply to all will be hidden"

- (id)initWithDestPath:(const string&)_path
        withSourceStat:(const struct stat &)_src_stat
   withDestinationStat:(const struct stat &)_dst_stat
            andContext:(shared_ptr<nc::ops::AsyncDialogResponse>)_ctx;

@end
