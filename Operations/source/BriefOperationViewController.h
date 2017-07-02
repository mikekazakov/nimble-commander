#pragma once

#include <Cocoa/Cocoa.h>

namespace nc::ops {
    class Operation;
}

@interface NCOpsBriefOperationViewController : NSViewController

- (instancetype)initWithOperation:(const shared_ptr<nc::ops::Operation>&)_operation;

@property (nonatomic, readonly) const shared_ptr<nc::ops::Operation>& operation;

@property bool shouldDelayAppearance;

@end
