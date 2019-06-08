// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include "BriefOperationView.h"

@implementation NCOpsBriefOperationView
{
    bool m_MouseOver;
}

@synthesize isMouseOver = m_MouseOver;

- (void) updateTrackingAreas
{
    // Init a single tracking area which covers whole view.
    
    if( self.trackingAreas.count != 0 )
        [self removeTrackingArea:self.trackingAreas[0]];
    
    const auto opts = NSTrackingMouseEnteredAndExited |
                      NSTrackingActiveAlways |
                      NSTrackingEnabledDuringMouseDrag;
    const auto tracking_area = [[NSTrackingArea alloc] initWithRect:self.bounds
                                                            options:opts
                                                              owner:self
                                                           userInfo:nil];
    
    const auto mouse = [self convertPoint:self.window.mouseLocationOutsideOfEventStream
                                 fromView:nil];
    
    static const auto dummy_event = [NSEvent otherEventWithType:NSApplicationDefined
                                                       location:{0,0}
                                                  modifierFlags:0
                                                      timestamp:0
                                                   windowNumber:0
                                                        context:nil
                                                        subtype:0
                                                          data1:0
                                                          data2:0];
    if( NSPointInRect(mouse, self.bounds) )
        [self mouseEntered:dummy_event];
    else
        [self mouseExited:dummy_event];
    
    [self addTrackingArea:tracking_area];
}

- (void)mouseEntered:(NSEvent *)[[maybe_unused]]_event
{
    if( m_MouseOver == true )
        return;
    
    [self willChangeValueForKey:@"isMouseOver"];
    m_MouseOver = true;
    [self didChangeValueForKey:@"isMouseOver"];
}

- (void)mouseExited:(NSEvent *)[[maybe_unused]]_event
{
    if( m_MouseOver == false )
        return;
    
    [self willChangeValueForKey:@"isMouseOver"];
    m_MouseOver = false;
    [self didChangeValueForKey:@"isMouseOver"];
}

@end
