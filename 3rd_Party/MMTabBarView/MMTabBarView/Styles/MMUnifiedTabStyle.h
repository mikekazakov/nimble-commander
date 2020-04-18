//
//  MMUnifiedTabStyle.h
//  --------------------
//
//  Created by Keith Blount on 30/04/2006.
//  Copyright 2006 Keith Blount. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "../MMTabStyle.h"

NS_ASSUME_NONNULL_BEGIN

@interface MMUnifiedTabStyle : NSObject <MMTabStyle>

@property (assign) CGFloat leftMarginForTabBarView;

@end

NS_ASSUME_NONNULL_END
