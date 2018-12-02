// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <memory>

namespace nc::ops {
    class Operation;
}

@interface NCOpsBriefOperationViewController : NSViewController

- (instancetype)initWithOperation:(const std::shared_ptr<nc::ops::Operation>&)_operation;

@property (nonatomic, readonly) const std::shared_ptr<nc::ops::Operation>& operation;

@property bool shouldDelayAppearance;

@end
