// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Habanero/dispatch_cpp.h>
#include <Utility/NSView+Sugar.h>

@implementation NSView (Sugar)

- (void) setNeedsDisplay
{
    if( dispatch_is_main_queue() )
        self.needsDisplay = true;
    else
        dispatch_to_main_queue( [=]{ self.needsDisplay = true; } );
}

@end
