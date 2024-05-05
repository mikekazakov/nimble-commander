// Copyright (C) 2017-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include "../AsyncDialogResponse.h"

@interface NCOpsFileAlreadyExistDialog : NSWindowController

@property(nonatomic) bool allowAppending;   // if this is true - "append" button will be enabled
@property(nonatomic) bool allowKeepingBoth; // if this is true - "keep both" button will be enabled
@property(nonatomic) bool singleItem;       // if this is true - "apply to all will be hidden"

- (id)initWithDestPath:(const std::string &)_path
         withSourceStat:(const struct stat &)_src_stat
    withDestinationStat:(const struct stat &)_dst_stat
             andContext:(std::shared_ptr<nc::ops::AsyncDialogResponse>)_ctx;

@end
