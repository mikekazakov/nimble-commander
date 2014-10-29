//
//  NSAffineTransform+MMTabBarViewExtensions.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/26/12.
//  Copyright (c) 2012 Michael Monscheuer. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSAffineTransform (MMTabBarViewExtensions)

- (NSAffineTransform *)mm_flipVertical:(NSRect)bounds;

@end
