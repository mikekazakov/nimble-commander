//
//  MMTabDragWindowController.h
//  MMTabBarView
//
//  Created by Kent Sutherland on 6/18/07.
//  Copyright 2007 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MMTabBarView.h"

#define kMMTabDragWindowAlpha 0.75
#define kMMTabDragAlphaInterval 0.15

@class MMTabDragView;

@interface MMTabDragWindowController : NSWindowController {
	MMTabBarTearOffStyle				_tearOffStyle;
	MMTabDragView						*_view;
	NSAnimation							*_animation;
	NSTimer								*_timer;

	BOOL								_showingAlternate;
	NSRect								_originalWindowFrame;
}
- (id)initWithImage:(NSImage *)image styleMask:(NSUInteger) styleMask tearOffStyle:(MMTabBarTearOffStyle)tearOffStyle;

- (NSImage *)image;
- (NSImage *)alternateImage;
- (void)setAlternateImage:(NSImage *)image;
- (BOOL)isAnimating;
- (void)switchImages;
@end
