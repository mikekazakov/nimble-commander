//
//  MMAttachedTabBarButtonCell.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/5/12.
//
//

#import "MMAttachedTabBarButtonCell.h"

#import "MMAttachedTabBarButton.h"

@implementation MMAttachedTabBarButtonCell

@synthesize isOverflowButton = _isOverflowButton;

- (id)init {
	if ((self = [super init])) {
        _isOverflowButton = NO;		
	}
	return self;
}

- (void)dealloc {
    [super dealloc];
}

- (MMAttachedTabBarButton *)controlView {
    return (MMAttachedTabBarButton *)[super controlView];
}

- (void)setControlView:(MMAttachedTabBarButton *)aView {
    [super setControlView:aView];
}

#pragma mark -
#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone {
    
    MMAttachedTabBarButtonCell *cellCopy = [super copyWithZone:zone];
    if (cellCopy) {
        cellCopy->_isOverflowButton = _isOverflowButton;
    }
    
    return cellCopy;
}

#pragma mark -
#pragma mark Archiving

- (void)encodeWithCoder:(NSCoder *)aCoder {
	[super encodeWithCoder:aCoder];

	if ([aCoder allowsKeyedCoding]) {
        [aCoder encodeBool:_isOverflowButton forKey:@"MMAttachedTabBarButtonCellIsOverflowButton"];
	}
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super initWithCoder:aDecoder])) {
		if ([aDecoder allowsKeyedCoding]) {
            
            _isOverflowButton = [aDecoder decodeBoolForKey:@"MMAttachedTabBarButtonCellIsOverflowButton"];
		}
	}
	return self;
}

@end
