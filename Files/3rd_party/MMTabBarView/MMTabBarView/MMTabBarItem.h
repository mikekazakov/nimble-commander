//
//  MMTabBarItem.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/29/12.
//  Copyright (c) 2012 Michael Monscheuer. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol MMTabBarItem <NSObject>

@optional

@property (copy)   NSString     *title;
@property (retain) NSImage      *icon;
@property (retain) NSImage      *largeImage;
@property (assign) NSInteger    objectCount;
@property (retain) NSColor      *objectCountColor;

@property (assign) BOOL isProcessing;
@property (assign) BOOL isEdited;
@property (assign) BOOL hasCloseButton;

@end
