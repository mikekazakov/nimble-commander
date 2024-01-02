// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

namespace nc::ops {
    class Pool;

}

// STA design - use it only from main queue
@interface NCOpsPoolViewController : NSViewController

- (instancetype) initWithPool:(nc::ops::Pool&)_pool;

@property (nonatomic, readonly) NSView *idleView;

@end
