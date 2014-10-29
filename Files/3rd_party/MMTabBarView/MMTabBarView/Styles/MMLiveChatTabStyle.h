//
//  MMLiveChatTabStyle.h
//  --------------------
//
//  Created by Keith Blount on 30/04/2006.
//  Copyright 2006 Keith Blount. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MMTabStyle.h"
#import "NSBezierPath+MMTabBarViewExtensions.h"

@interface MMLiveChatTabStyle : NSObject <MMTabStyle> {
	NSImage				*liveChatCloseButton;
	NSImage				*liveChatCloseButtonDown;
	NSImage				*liveChatCloseButtonOver;
	NSImage				*liveChatCloseDirtyButton;
	NSImage				*liveChatCloseDirtyButtonDown;
	NSImage				*liveChatCloseDirtyButtonOver;

	NSDictionary		*_objectCountStringAttributes;

	CGFloat				_leftMargin;
}

@property (assign) CGFloat leftMarginForTabBarView;

#pragma mark Live Chat Tab Style Drawings

// the funnel point for modify tab button drawing in a subclass
- (void)drawBezelInRect:(NSRect)aRect withCapMask:(MMBezierShapeCapMask)capMask usingStatesOfAttachedButton:(MMAttachedTabBarButton *)button ofTabBarView:(MMTabBarView *)tabBarView;

@end
