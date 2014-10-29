//
//  MMTabBarButton.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#import <Cocoa/Cocoa.h>

#import "MMTabBarView.h"
#import "MMRolloverButton.h"
#import "MMProgressIndicator.h"
#import "MMTabBarButtonCell.h"

@class MMTabBarView;

@protocol MMTabStyle;

@interface MMTabBarButton : MMRolloverButton {

        // the layouted frame rect
    NSRect _stackingFrame;
    
        // close button
    MMRolloverButton *_closeButton;
    
        // progress indicator
	MMProgressIndicator    *_indicator;    
}

@property (assign) NSRect stackingFrame;
@property (retain) MMRolloverButton *closeButton;
@property (assign) SEL closeButtonAction;
@property (readonly, retain) MMProgressIndicator *indicator;

- (id)initWithFrame:(NSRect)frame;

- (MMTabBarButtonCell *)cell;
- (void)setCell:(MMTabBarButtonCell *)aCell;

- (MMTabBarView *)tabBarView;

- (void)updateCell;

#pragma mark Dividers

- (BOOL)shouldDisplayLeftDivider;
- (BOOL)shouldDisplayRightDivider;

#pragma mark Determine Sizes

- (CGFloat)minimumWidth;
- (CGFloat)desiredWidth;

#pragma mark Interfacing Cell

- (id <MMTabStyle>)style;
- (void)setStyle:(id <MMTabStyle>)newStyle;

- (MMTabStateMask)tabState;
- (void)setTabState:(MMTabStateMask)newState;

- (NSImage *)icon;
- (void)setIcon:(NSImage *)anIcon;
- (NSImage *)largeImage;
- (void)setLargeImage:(NSImage *)anImage;
- (BOOL)showObjectCount;
- (void)setShowObjectCount:(BOOL)newState;
- (NSInteger)objectCount;
- (void)setObjectCount:(NSInteger)newCount;
- (NSColor *)objectCountColor;
- (void)setObjectCountColor:(NSColor *)newColor;
- (BOOL)isEdited;
- (void)setIsEdited:(BOOL)newState;
- (BOOL)isProcessing;
- (void)setIsProcessing:(BOOL)newState;

- (void)updateImages;

#pragma mark Close Button Support

- (BOOL)shouldDisplayCloseButton;

- (BOOL)hasCloseButton;
- (void)setHasCloseButton:(BOOL)newState;

- (BOOL)suppressCloseButton;
- (void)setSuppressCloseButton:(BOOL)newState;

@end
