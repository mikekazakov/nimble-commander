//
//  MMRolloverButton.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/8/12.
//

#import <Cocoa/Cocoa.h>

#import "MMRolloverButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMRolloverButton : NSButton 

#pragma mark Cell Interface

@property (strong) NSImage *rolloverImage;
@property (assign) MMRolloverButtonType rolloverButtonType;

@property (readonly) BOOL mouseHovered;

@property (assign) BOOL simulateClickOnMouseHovered;

@end

NS_ASSUME_NONNULL_END
