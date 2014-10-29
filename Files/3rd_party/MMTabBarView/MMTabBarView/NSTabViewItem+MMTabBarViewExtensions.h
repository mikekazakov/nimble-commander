//
//  NSTabViewItem+MMTabBarViewExtensions.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/29/12.
//  Copyright (c) 2012 Michael Monscheuer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MMTabBarItem.h"

@interface NSTabViewItem (MMTabBarViewExtensions) <MMTabBarItem>

@property (retain) NSImage *largeImage;
@property (retain) NSImage *icon;
@property (assign) BOOL isProcessing;
@property (assign) NSInteger objectCount;
@property (retain) NSColor *objectCountColor;
@property (assign) BOOL showObjectCount;
@property (assign) BOOL isEdited;
@property (assign) BOOL hasCloseButton;

@end
