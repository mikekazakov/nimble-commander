//
//  MMOverflowPopUpButtonCell.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/24/12.
//  Copyright (c) 2012 Michael Monscheuer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMOverflowPopUpButton.h"

@class MMImageTransitionAnimation;

@interface MMOverflowPopUpButtonCell : NSPopUpButtonCell <NSAnimationDelegate> {

@private
    MMCellBezelDrawingBlock _bezelDrawingBlock;
    NSImage *_image;
    NSImage *_secondImage;
    CGFloat _secondImageAlpha;
}

@property (copy) MMCellBezelDrawingBlock bezelDrawingBlock;
@property (retain) NSImage *image;
@property (retain) NSImage *secondImage;
@property (assign) CGFloat secondImageAlpha;

- (void)drawImage:(NSImage *)image withFrame:(NSRect)frame inView:(NSView *)controlView alpha:(CGFloat)alpha;

@end
