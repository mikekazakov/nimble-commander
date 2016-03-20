//
//  Application.m
//  Files
//
//  Created by Michael G. Kazakov on 04/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

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
        cout << "Exception caught: " << e.what() << endl;
    }
    catch(exception *e)
    {
        cout << "Exception caught: " << e->what() << endl;
    }
    catch(...)
    {
        cout << "Caught an unhandled exception!" << endl;
    }
}

- (NSEvent *)nextEventMatchingMask:(NSUInteger)mask untilDate:(NSDate *)expiration inMode:(NSString *)mode dequeue:(BOOL)deqFlag
{
    try
    {
        return [super nextEventMatchingMask:mask untilDate:expiration inMode:mode dequeue:deqFlag];
    }
    catch(exception &e)
    {
        cout << "Exception caught: " << e.what() << endl;
    }
    catch(exception *e)
    {
        cout << "Exception caught: " << e->what() << endl;
    }
    catch(...)
    {
        cout << "Caught an unhandled exception!" << endl;
    }

    return nil;
}

@end
