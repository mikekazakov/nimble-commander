// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include <Utility/NSObject+MassObserving.h>

@implementation NSObject (MassObserving)
- (void)addObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys
{
    for(NSString *s in keys)
        [self addObserver:observer forKeyPath:s options:0 context:nil];
}

- (void)addObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys options:(NSKeyValueObservingOptions)options context:(void *)context
{
    for(NSString *s in keys)
        [self addObserver:observer forKeyPath:s options:options context:context];
}

- (void)removeObserver:(NSObject *)observer forKeyPaths:(NSArray*)keys
{
    for(NSString *s in keys)
        [self removeObserver:observer forKeyPath:s];
}
@end
