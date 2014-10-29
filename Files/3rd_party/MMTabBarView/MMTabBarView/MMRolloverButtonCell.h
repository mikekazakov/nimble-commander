//
//  MMRolloverButtonCell.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/8/12.
//

#import <Cocoa/Cocoa.h>

typedef enum MMRolloverButtonType : NSUInteger
{
    MMRolloverActionButton = 0,
    MMRolloverSwitchButton
} MMRolloverButtonType;

@interface MMRolloverButtonCell : NSButtonCell {

@private
    NSImage *_rolloverImage;
    BOOL _mouseHovered;
    MMRolloverButtonType _rolloverButtonType;
    BOOL _simulateClickOnMouseHovered;
}

@property (readonly) BOOL mouseHovered;
@property (retain) NSImage *rolloverImage;
@property (assign) MMRolloverButtonType rolloverButtonType;
@property (assign) BOOL simulateClickOnMouseHovered;

#pragma mark Tracking Area Support
- (void)addTrackingAreasForView:(NSView *)controlView inRect:(NSRect)cellFrame withUserInfo:(NSDictionary *)userInfo mouseLocation:(NSPoint)mouseLocation;
- (void)mouseEntered:(NSEvent *)event;
- (void)mouseExited:(NSEvent *)event;

@end
