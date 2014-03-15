//
//  OperationsSummaryView.m
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "GenericOperationView.h"

@implementation GenericOperationView
{
    NSButton *m_PauseButton;
    NSButton *m_StopButton;
    NSProgressIndicator *m_Progress;
    NSTextField *m_Caption;
    NSButton *m_DialogButton;
}
@synthesize PauseButton = m_PauseButton;
@synthesize StopButton = m_StopButton;
@synthesize Progress = m_Progress;
@synthesize Caption = m_Caption;
@synthesize DialogButton = m_DialogButton;


- (void)ToggleButtonsVisiblity:(BOOL)_visible
{
    m_PauseButton.hidden = !_visible;
    m_StopButton.hidden = !_visible;
}

- (void)viewWillMoveToSuperview:(NSView *)_view
{
    [super viewWillMoveToSuperview:_view];
    
    if (!m_PauseButton) m_PauseButton = [self viewWithTag:1];
    if (!m_StopButton) m_StopButton = [self viewWithTag:2];
    if (!m_Caption) m_Caption = [self viewWithTag:4];
    if (!m_DialogButton) m_DialogButton = [self viewWithTag:5];
    if (!m_Progress)
    {
        for (NSView *view in self.subviews) {
            if ([view isKindOfClass:NSProgressIndicator.class])
            {
                m_Progress = (NSProgressIndicator *)view;
                break;
            }
        }
    }
    
    [self ToggleButtonsVisiblity:NO];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
    [self ToggleButtonsVisiblity:YES];
}

- (void)mouseExited:(NSEvent *)theEvent
{
    [self ToggleButtonsVisiblity:NO];
}

- (void)updateTrackingAreas
{
    // Init a single tracking area which covers whole view.
    
    if ([self.trackingAreas count])
    {
        // Remove previous tracking area.
        assert([self.trackingAreas count] == 1);
        [self removeTrackingArea:self.trackingAreas[0]];
    }
    
    // Add new tracking area.
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingEnabledDuringMouseDrag);
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options:opts owner:self userInfo:nil];
    
    // Check if mouse inside or outside of the view, and call appropriate method.
    NSPoint mouseLocation = [[self window] mouseLocationOutsideOfEventStream];
    mouseLocation = [self convertPoint: mouseLocation
                              fromView: nil];
    
    if (NSPointInRect(mouseLocation, [self bounds]))
        [self mouseEntered: nil];
    else
        [self mouseExited: nil];
    
    
    [self addTrackingArea:trackingArea];
}

- (BOOL)wantsDefaultClipping
{
    return NO;
}

@end
