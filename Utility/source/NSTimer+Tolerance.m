#include <Utility/NSTimer+Tolerance.h>

@implementation NSTimer (Tolerance)

- (void) setDefaultTolerance
{
    self.tolerance = self.timeInterval/10.;
}

@end
