//
//  NSBezierPath+MMTabBarViewExtensions.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/26/12.
//  Copyright (c) 2012 Michael Monscheuer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef enum MMBezierShapeCapMask : NSUInteger {
    MMBezierShapeLeftCap           = 0x0001,
    MMBezierShapeRightCap          = 0x0002,
    
    MMBezierShapeAllCaps           = 0x000F,
    
    MMBezierShapeFlippedVertically = 0x1000,
    MMBezierShapeFillPath          = 0x2000
} MMBezierShapeCapMask;

@interface NSBezierPath (MMTabBarViewExtensions)

+ (NSBezierPath *)bezierPathWithCardInRect:(NSRect)aRect radius:(CGFloat)radius capMask:(MMBezierShapeCapMask)mask;

+ (NSBezierPath *)bezierPathWithRoundedRect:(NSRect)aRect radius:(CGFloat)radius capMask:(MMBezierShapeCapMask)mask;

@end
