// Copyright (C) 2016-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Base/dispatch_cpp.h>
#include <Utility/NSView+Sugar.h>

@implementation NSView (Sugar)

- (void)setNeedsDisplay
{
    if( nc::dispatch_is_main_queue() )
        self.needsDisplay = true;
    else
        dispatch_to_main_queue([=] { self.needsDisplay = true; });
}

@end
