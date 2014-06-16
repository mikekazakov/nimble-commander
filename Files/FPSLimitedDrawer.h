//
//  FPSBasedDrawer.h
//  Files
//
//  Created by Michael G. Kazakov on 16.06.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

@interface FPSLimitedDrawer : NSObject

- (id) initWithView:(NSView*)_view;

@property unsigned fps; // zero fps means that invalidation will cause setNeedDisplay immediately
@property (readonly) NSView *view;

- (void) invalidate;


@end
