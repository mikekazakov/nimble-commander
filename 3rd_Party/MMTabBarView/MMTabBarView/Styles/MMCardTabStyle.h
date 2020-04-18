//
//  MMCardTabStyle.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/3/12.
//
//

#import <Cocoa/Cocoa.h>
#import "../MMTabStyle.h"
#import "../NSBezierPath+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMCardTabStyle : NSObject <MMTabStyle>

@property (assign) CGFloat horizontalInset;
@property (assign) CGFloat topMargin;

#pragma mark Card Tab Style Drawings

// the funnel point for modify tab button drawing in a subclass
- (void)drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView;

@end

NS_ASSUME_NONNULL_END
