// Copyright (C) 2015-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Application.h"

@implementation Application

- (id) init
{
    self = [super init];
    if(self) {
    }
    return self;
}

- (void)sendEvent:(NSEvent *)theEvent
{
    try
    {
        [super sendEvent:theEvent];
    }
    catch(exception &e)
    {
        cerr << "Exception caught: " << e.what() << endl;
    }
    catch(exception *e)
    {
        cerr << "Exception caught: " << e->what() << endl;
    }
    catch(...)
    {
        cerr << "Caught an unhandled exception!" << endl;
    }
}

- (NSEvent *)nextEventMatchingMask:(NSEventMask)mask
                         untilDate:(NSDate *)expiration
                            inMode:(NSString *)mode
                           dequeue:(BOOL)deqFlag
{
    try
    {
        return [super nextEventMatchingMask:mask untilDate:expiration inMode:mode dequeue:deqFlag];
    }
    catch(exception &e)
    {
        cerr << "Exception caught: " << e.what() << endl;
    }
    catch(exception *e)
    {
        cerr << "Exception caught: " << e->what() << endl;
    }
    catch(...)
    {
        cerr << "Caught an unhandled exception!" << endl;
    }

    return nil;
}

@end
