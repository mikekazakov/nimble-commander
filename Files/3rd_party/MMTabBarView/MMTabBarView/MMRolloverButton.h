//
//  MMRolloverButton.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/8/12.
//

#import <Cocoa/Cocoa.h>

#import "MMRolloverButtonCell.h"

@interface MMRolloverButton : NSButton 

#pragma mark Cell Interface

- (NSImage *)rolloverImage;
- (void)setRolloverImage:(NSImage *)image;

- (MMRolloverButtonType)rolloverButtonType;
- (void)setRolloverButtonType:(MMRolloverButtonType)aType;

- (BOOL)mouseHovered;

- (BOOL)simulateClickOnMouseHovered;
- (void)setSimulateClickOnMouseHovered:(BOOL)flag;

@end