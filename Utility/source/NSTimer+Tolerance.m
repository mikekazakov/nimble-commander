// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/NSTimer+Tolerance.h>

@implementation NSTimer (Tolerance)

- (void) setDefaultTolerance
{
    self.tolerance = self.timeInterval/10.;
}

@end
