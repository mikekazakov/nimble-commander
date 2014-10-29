//
//  MMOverflowPopUpButton.h
//  MMTabBarView
//
//  Created by John Pannell on 11/4/05.
//  Copyright 2005 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

typedef void (^MMCellBezelDrawingBlock)(NSCell *cell, NSRect frame, NSView *controlView);

@interface MMOverflowPopUpButton : NSPopUpButton {

    BOOL _isAnimating;                      // pulsating animation of image and second image
}

// accessors
- (NSImage *)secondImage;
- (void)setSecondImage:(NSImage *)anImage;

// archiving
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

// bezel drawing
- (MMCellBezelDrawingBlock)bezelDrawingBlock;
- (void)setBezelDrawingBlock:(MMCellBezelDrawingBlock)aBlock;

@end
