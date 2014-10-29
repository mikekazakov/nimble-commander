//
//  MMAttachedTabBarButtonCell.h
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#import "MMTabBarButtonCell.h"
#import "MMTabBarView.h"

@class MMAttachedTabBarButton;

@interface MMAttachedTabBarButtonCell : MMTabBarButtonCell {

    BOOL _isOverflowButton;
}

@property (assign) BOOL isOverflowButton;

- (MMAttachedTabBarButton *)controlView;
- (void)setControlView:(MMAttachedTabBarButton *)aView;

@end
