//
//  MMTabBarButtonCell.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#import <Cocoa/Cocoa.h>

#import "MMTabBarView.h"
#import "MMRolloverButton.h"

@class MMTabBarView;
@class MMTabBarButton;
@class MMProgressIndicator;

@protocol MMTabStyle;

typedef enum MMCloseButtonImageType : NSUInteger
{
    MMCloseButtonImageTypeStandard = 0,
    MMCloseButtonImageTypeRollover,
    MMCloseButtonImageTypePressed,
    MMCloseButtonImageTypeDirty,
    MMCloseButtonImageTypeDirtyRollover,
    MMCloseButtonImageTypeDirtyPressed
} MMCloseButtonImageType;

typedef enum MMTabStateMask : NSUInteger {
	MMTab_LeftIsSelectedMask		= 1 << 2,
	MMTab_RightIsSelectedMask		= 1 << 3,
    
    MMTab_LeftIsSliding             = 1 << 4,
    MMTab_RightIsSliding            = 1 << 5,
    
    MMTab_PlaceholderOnLeft         = 1 << 6,
    MMTab_PlaceholderOnRight        = 1 << 7,
    
	MMTab_PositionLeftMask			= 1 << 8,
	MMTab_PositionMiddleMask		= 1 << 9,
	MMTab_PositionRightMask         = 1 << 10,
	MMTab_PositionSingleMask		= 1 << 11
} MMTabStateMask;

@interface MMTabBarButtonCell : MMRolloverButtonCell {

@private
    id <MMTabStyle> _style;

        // state
	MMTabStateMask		    _tabState;
        
        // cell values
    NSImage                 *_icon;
    NSImage                 *_largeImage;
    BOOL                    _showObjectCount;
	NSInteger				_objectCount;
	NSColor                 *_objectCountColor;
	BOOL					_isEdited;
    BOOL                    _isProcessing;
        
        // close button
	BOOL					_hasCloseButton;
	BOOL					_suppressCloseButton;
	BOOL					_closeButtonOver;
}

@property (retain) id <MMTabStyle> style;

@property (retain) NSImage *icon;
@property (retain) NSImage *largeImage;
@property (assign) BOOL showObjectCount;
@property (assign) NSInteger objectCount;
@property (retain) NSColor *objectCountColor;
@property (assign) BOOL isEdited;
@property (assign) BOOL isProcessing;

@property (assign) BOOL hasCloseButton;
@property (assign) BOOL suppressCloseButton;

@property (assign) MMTabStateMask tabState;

+ (NSColor *)defaultObjectCountColor;

- (MMTabBarButton *)controlView;
- (void)setControlView:(MMTabBarButton *)aView;

- (MMTabBarView *)tabBarView;

- (void)updateImages;

#pragma mark Progress Indicator Support

- (MMProgressIndicator *)indicator;

#pragma mark Close Button Support

- (MMRolloverButton *)closeButton;
- (BOOL)shouldDisplayCloseButton;
- (NSImage *)closeButtonImageOfType:(MMCloseButtonImageType)type;

#pragma mark Cell Values

- (NSAttributedString *)attributedStringValue;
- (NSAttributedString *)attributedObjectCountStringValue;

#pragma mark Determining Cell Size

- (NSRect)drawingRectForBounds:(NSRect)theRect;
- (NSRect)titleRectForBounds:(NSRect)theRect ;
- (NSRect)iconRectForBounds:(NSRect)theRect;
- (NSRect)largeImageRectForBounds:(NSRect)theRect;
- (NSRect)indicatorRectForBounds:(NSRect)theRect;
- (NSSize)objectCounterSize;
- (NSRect)objectCounterRectForBounds:(NSRect)theRect;
- (NSRect)closeButtonRectForBounds:(NSRect)theRect;

- (CGFloat)minimumWidthOfCell;
- (CGFloat)desiredWidthOfCell;

#pragma mark Drawing

- (void)drawWithFrame:(NSRect) cellFrame inView:(NSView *)controlView;
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (void)drawBezelWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (void)drawLargeImageWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawIconWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawTitleWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawObjectCounterWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawIndicatorWithFrame:(NSRect)frame inView:(NSView *)controlView;
- (void)drawCloseButtonWithFrame:(NSRect)frame inView:(NSView *)controlView;

/*
#pragma mark Tracking Area Support

- (void)addTrackingAreasForView:(NSView *)view inRect:(NSRect)cellFrame withUserInfo:(NSDictionary *)userInfo mouseLocation:(NSPoint)currentPoint;
- (void)mouseEntered:(NSEvent *)theEvent;
- (void)mouseExited:(NSEvent *)theEvent;
*/
@end
