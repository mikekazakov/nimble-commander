#pragma once

@interface AskingForRatingOverlayView : NSControl

/**
 * 0: discard button was clicked (defualt)
 * [1-5]: amount of stars assigned
 */
@property (nonatomic, readonly) int userRating;

- (instancetype) initWithFrame:(NSRect)frameRect;

@end
