//
//  MMCardTabStyle.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/3/12.
//
//

#import <Cocoa/Cocoa.h>
#import "MMTabStyle.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"

@interface MMCardTabStyle : NSObject <MMTabStyle>
{
    NSImage *cardCloseButton;
    NSImage *cardCloseButtonDown;
    NSImage *cardCloseButtonOver;
    NSImage *cardCloseDirtyButton;
    NSImage *cardCloseDirtyButtonDown;
    NSImage *cardCloseDirtyButtonOver;
	    
    CGFloat _horizontalInset;
    CGFloat _topMargin;
}

@property (assign) CGFloat horizontalInset;
@property (assign) CGFloat topMargin;

#pragma mark Card Tab Style Drawings

// the funnel point for modify tab button drawing in a subclass
- (void)drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView;

@end
