//
//  MMTabPasteboardItem.m
//  MMTabBarView
//
//  Created by Michael Monscheuer on 9/11/12.
//
//

#import "MMTabPasteboardItem.h"

@implementation MMTabPasteboardItem

@synthesize sourceIndex = _sourceIndex;

- (id)init {
    self = [super init];
    if (self) {
        _sourceIndex = NSNotFound;
    }
    return self;
}

@end
