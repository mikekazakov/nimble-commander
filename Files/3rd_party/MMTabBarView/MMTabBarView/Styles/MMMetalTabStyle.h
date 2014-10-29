//
//  MMMetalTabStyle.h
//  MMTabBarView
//
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MMTabStyle.h"

@interface MMMetalTabStyle : NSObject <MMTabStyle> {
	NSImage					*metalCloseButton;
	NSImage					*metalCloseButtonDown;
	NSImage					*metalCloseButtonOver;
	NSImage					*metalCloseDirtyButton;
	NSImage					*metalCloseDirtyButtonDown;
	NSImage					*metalCloseDirtyButtonOver;

	NSDictionary			*_objectCountStringAttributes;
}

- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

@end
