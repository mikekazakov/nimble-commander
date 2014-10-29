//
//  MMTabDragWindow.h
//  MMTabBarView
//
//  Created by Kent Sutherland on 6/1/06.
//  Copyright 2006 Kent Sutherland. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MMTabDragView;

@interface MMTabDragWindow : NSWindow {
	MMTabDragView					*_dragView;
}
+ (MMTabDragWindow *)dragWindowWithImage:(NSImage *)image styleMask:(NSUInteger)styleMask;

- (id)initWithImage:(NSImage *)image styleMask:(NSUInteger)styleMask;
- (MMTabDragView *)dragView;
@end
