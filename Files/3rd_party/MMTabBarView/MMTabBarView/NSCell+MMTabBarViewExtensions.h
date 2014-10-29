//
//  NSCell+MMTabBarViewExtensions.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/25/12.
//  Copyright (c) 2012 Michael Monscheuer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSCell (MMTabBarViewExtensions)

#pragma mark Image Scaling

- (NSSize)mm_scaleImageWithSize:(NSSize)imageSize toFitInSize:(NSSize)canvasSize scalingType:(NSImageScaling)scalingType;

@end
