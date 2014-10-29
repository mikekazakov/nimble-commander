//
//  MMAquaTabStyle.h
//  MMTabBarView
//
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MMTabStyle.h"

@interface MMAquaTabStyle : NSObject <MMTabStyle> {
	NSImage									*aquaTabBg;
	NSImage									*aquaTabBgDown;
	NSImage									*aquaTabBgDownGraphite;
	NSImage									*aquaTabBgDownNonKey;
	NSImage									*aquaDividerDown;
	NSImage									*aquaDivider;
	NSImage									*aquaCloseButton;
	NSImage									*aquaCloseButtonDown;
	NSImage									*aquaCloseButtonOver;
	NSImage									*aquaCloseDirtyButton;
	NSImage									*aquaCloseDirtyButtonDown;
	NSImage									*aquaCloseDirtyButtonOver;
}

- (void)loadImages;

- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

@end
