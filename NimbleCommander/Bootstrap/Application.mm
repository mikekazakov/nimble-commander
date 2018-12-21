// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#include "Application.h"
#include <exception>
#include <iostream>

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
    catch(std::exception &e)
    {
        std::cerr << "Exception caught: " << e.what() << std::endl;
    }
    catch(...)
    {
        std::cerr << "Caught an unhandled exception!" << std::endl;
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
    catch(std::exception &e)
    {
        std::cerr << "Exception caught: " << e.what() << std::endl;
    }
    catch(...)
    {
        std::cerr << "Caught an unhandled exception!" << std::endl;
    }

    return nil;
}

@end
