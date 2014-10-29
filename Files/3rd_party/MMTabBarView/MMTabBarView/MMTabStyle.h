//
//  MMTabStyle.h
//  MMTabBarView
//
//  Created by John Pannell on 2/17/06.
//  Copyright 2006 Positive Spin Media. All rights reserved.
//

/*
   Protocol to be observed by all style delegate objects.  These objects handle the drawing responsibilities for MMTabBarButtonCell; once the control has been assigned a style, the background and button cells draw consistent with that style.  Design pattern and implementation by David Smith, Seth Willits, and Chris Forsythe, all touch up and errors by John P. :-)
 */

#import "MMTabBarButtonCell.h"
#import "MMAttachedTabBarButtonCell.h"
#import "MMOverflowPopUpButtonCell.h"
#import "MMTabBarView.h"

@protocol MMTabStyle <NSObject>

// identity
+ (NSString *)name;
- (NSString *)name;

@optional

// tab view specific parameters
- (BOOL)supportsOrientation:(MMTabBarOrientation)orientation forTabBarView:(MMTabBarView *)tabBarView;
- (CGFloat)leftMarginForTabBarView:(MMTabBarView *)tabBarView;
- (CGFloat)rightMarginForTabBarView:(MMTabBarView *)tabBarView;
- (CGFloat)topMarginForTabBarView:(MMTabBarView *)tabBarView;
- (CGFloat)bottomMarginForTabBarView:(MMTabBarView *)tabBarView;
- (NSSize)addTabButtonSizeForTabBarView:(MMTabBarView *)tabBarView;
- (NSRect)addTabButtonRectForTabBarView:(MMTabBarView *)tabBarView;
- (NSSize)overflowButtonSizeForTabBarView:(MMTabBarView *)tabBarView;
- (NSRect)overflowButtonRectForTabBarView:(MMTabBarView *)tabBarView;
- (CGFloat)heightOfTabBarButtonsForTabBarView:(MMTabBarView *)tabBarView;

- (void)updateAddButton:(MMRolloverButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView;
- (void)updateOverflowPopUpButton:(MMOverflowPopUpButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView;

// cell values
- (NSAttributedString *)attributedObjectCountStringValueForTabCell:(MMTabBarButtonCell *)cell;
- (NSAttributedString *)attributedStringValueForTabCell:(MMTabBarButtonCell *)cell;

// Constraints
- (CGFloat)minimumWidthOfTabCell:(MMTabBarButtonCell *)cell;
- (CGFloat)desiredWidthOfTabCell:(MMTabBarButtonCell *)cell;

// Update Buttons
- (BOOL)updateCloseButton:(MMRolloverButton *)closeButton ofTabCell:(MMTabBarButtonCell *)cell; // returning NO will hide the close button

// Providing Images
- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type forTabCell:(MMTabBarButtonCell *)cell;

// Determining Cell Size
- (NSRect)drawingRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;
- (NSSize)closeButtonSizeForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;
- (NSRect)closeButtonRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

- (NSRect)titleRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;
- (NSRect)iconRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;
- (NSRect)largeImageRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;
- (NSRect)indicatorRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;
- (NSSize)objectCounterSizeOfTabCell:(MMTabBarButtonCell *)cell;
- (NSRect)objectCounterRectForBounds:(NSRect)theRect ofTabCell:(MMTabBarButtonCell *)cell;

// Drawing
- (void)drawTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;
- (void)drawBezelOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;
- (void)drawButtonBezelsOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;
- (void)drawBezelOfButton:(MMAttachedTabBarButton *)button atIndex:(NSUInteger)index inButtons:(NSArray *)buttons indexOfSelectedButton:(NSUInteger)selIndex tabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;
- (void)drawBezelOfOverflowButton:(MMOverflowPopUpButton *)overflowButton ofTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;
- (void)drawInteriorOfTabBarView:(MMTabBarView *)tabBarView inRect:(NSRect)rect;

- (void)drawTabBarCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawBezelOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawInteriorOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawTitleOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawIconOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawLargeImageOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawIndicatorOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawObjectCounterOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawCloseButtonOfTabCell:(MMTabBarButtonCell *)cell withFrame:(NSRect)frame inView:(NSView *)controlView;

// Drag & Drop Support
- (NSRect)draggingRectForTabButton:(MMAttachedTabBarButton *)aButton ofTabBarView:(MMTabBarView *)tabBarView;

@end