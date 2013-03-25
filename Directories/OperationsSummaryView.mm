//
//  OperationsSummaryView.m
//  Directories
//
//  Created by Pavel Dogurevich on 25.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "OperationsSummaryView.h"

@interface OperationsSummaryView ()

- (void)ToggleButtonsVisiblity:(BOOL)_visible;

@end

@implementation OperationsSummaryView

- (void)ToggleButtonsVisiblity:(BOOL)_visible
{
    [[self.PauseButton animator] setAlphaValue:(_visible ? 0.6 : 0.0)];
    [[self.PauseButton animator] setHidden:!_visible];
    [[self.StopButton animator] setAlphaValue:(_visible ? 0.6 : 0.0)];
    [[self.StopButton animator] setHidden:!_visible];
}

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
    }
    return self;
}

- (void)awakeFromNib
{
    [self.PauseButton setHidden:YES];
    [self.PauseButton setAlphaValue:0.0];
    [self.StopButton setHidden:YES];
    [self.StopButton setAlphaValue:0.0];
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
    
    int opts = (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways);
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options:opts owner:self userInfo:nil];
    
    [self addTrackingArea:trackingArea];
}

@end
