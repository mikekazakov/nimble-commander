//
//  PanelFastSearchPopupViewController.m
//  Files
//
//  Created by Michael G. Kazakov on 10.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "PanelFastSearchPopupViewController.h"
#import "Common.h"

static const uint64_t g_FadeDelay   = 5000000000; // 5 sec
static const double   g_FadeTime    = 0.7; // 0.7 sec

@implementation PanelFastSearchPopupViewController
{
    void (^m_OnPrev)();
    void (^m_OnNext)();
    uint64_t m_LastUpdateTime;
    bool     m_FadingOut;
}

- (id) init
{
    self = [super initWithNibName:NSStringFromClass(self.class) bundle:nil];
    if(self) {
        [self loadView];
        m_LastUpdateTime = 0;
        m_FadingOut = false;
    }
    return self;
}

- (void) PopUpWithView:(NSView*)_view
{
    NSView *sup = [[_view superview] superview];
    assert(sup);
    
    NSView *me = [self view];
    CGColorRef color = CGColorCreateGenericRGB(0.5, 0.5, 0.5, 0.6);
    [me layer].backgroundColor = color;
    [me layer].cornerRadius = 10.;
    CGColorRelease(color);
    
    [sup addSubview:me positioned:NSWindowAbove relativeTo:nil];
    
    NSLayoutConstraint *c1 = [NSLayoutConstraint constraintWithItem:me
                                                          attribute:NSLayoutAttributeCenterX
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:_view
                                                          attribute:NSLayoutAttributeCenterX
                                                         multiplier:1
                                                           constant:0];
    NSLayoutConstraint *c2 = [NSLayoutConstraint constraintWithItem:me
                                                          attribute:NSLayoutAttributeBottom
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:_view
                                                          attribute:NSLayoutAttributeBottom
                                                         multiplier:1
                                                           constant:0];
    NSLayoutConstraint *c3 = [NSLayoutConstraint constraintWithItem:me
                                                          attribute:NSLayoutAttributeWidth
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:nil
                                                          attribute:NSLayoutAttributeNotAnAttribute
                                                         multiplier:1
                                                           constant:235];
    NSLayoutConstraint *c4 = [NSLayoutConstraint constraintWithItem:me
                                                          attribute:NSLayoutAttributeHeight
                                                          relatedBy:NSLayoutRelationEqual
                                                             toItem:nil
                                                          attribute:NSLayoutAttributeNotAnAttribute
                                                         multiplier:1
                                                           constant:35];
    [sup addConstraint:c1];
    [sup addConstraint:c2];
    [sup addConstraint:c3];
    [sup addConstraint:c4];
    
    [self.Stepper setMinValue:-1];
    [self.Stepper setMaxValue:1];
    [self.Stepper setIncrement:-1];
    [self.Stepper setIntegerValue:0];
    [self.Stepper setHidden:(m_OnPrev == nil && m_OnNext == nil)];
    
    [[self.Label cell] setBackgroundStyle:NSBackgroundStyleRaised];
    
    [[self view] setHidden:false];
}

- (void) PopOut
{
    if(m_FadingOut)
        return;

    m_OnNext = 0;
    m_OnPrev = 0;
    m_FadingOut = true;
    CABasicAnimation* fadeAnim = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fadeAnim.fromValue = [NSNumber numberWithFloat: [[self view] layer].opacity];
    fadeAnim.toValue = [NSNumber numberWithFloat:0.0];
    fadeAnim.duration = g_FadeTime;
    [[[self view] layer] addAnimation:fadeAnim forKey:@"opacity"];
    [[self view] layer].opacity = 0.0;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(),
                   ^{
                       [[self view] removeFromSuperview];
                   });
}

- (void) UpdateWithString:(NSString*)_string Matches:(int)_matches
{
    [self.TextField setStringValue:_string];
    
    if(_matches == 0)
    {
        [self.Label setStringValue:@"Not found"];
        [self.Stepper setEnabled:false];        
    }
    else if(_matches == 1)
    {
        [self.Label setStringValue:[NSString stringWithFormat:@"%i match", _matches]];
        [self.Stepper setEnabled:false];
    }
    else
    {
        [self.Label setStringValue:[NSString stringWithFormat:@"%i matches", _matches]];
        [self.Stepper setEnabled:true];
    }
    
    m_LastUpdateTime = GetTimeInNanoseconds();

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, g_FadeDelay+1000), dispatch_get_main_queue(),
                   ^{
                        if(m_LastUpdateTime + g_FadeDelay <= GetTimeInNanoseconds() &&
                           !m_FadingOut)
                        {
                            [self PopOut];
                            if(self.OnAutoPopOut != nil)
                                self.OnAutoPopOut();
                        }
                   });
}

- (IBAction)OnStepper:(id)sender
{
    if([self.Stepper intValue] > 0) {
        if(m_OnNext) m_OnNext();
    }
    else {
        if(m_OnPrev) m_OnPrev();
    }
    
    [self.Stepper setIntegerValue:0];
}

- (void) SetHandlers:(void (^)())_on_prev Next:(void (^)())_on_next
{
    m_OnPrev = _on_prev;
    m_OnNext = _on_next;
}

@end
