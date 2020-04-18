//
//  MMLiveChatTabStyle.h
//  --------------------
//
//  Created by Keith Blount on 30/04/2006.
//  Copyright 2006 Keith Blount. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "../MMTabStyle.h"
#import "../NSBezierPath+MMTabBarViewExtensions.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMLiveChatTabStyle : NSObject <MMTabStyle>

@property (assign) CGFloat leftMarginForTabBarView;

#pragma mark Live Chat Tab Style Drawings

// the funnel point for modify tab button drawing in a subclass
- (void)drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView;

@end

NS_ASSUME_NONNULL_END
