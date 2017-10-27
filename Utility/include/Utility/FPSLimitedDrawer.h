// Copyright (C) 2014-2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface FPSLimitedDrawer : NSObject

- (id) initWithView:(NSView*)_view;

/**
 * A view Drawer is attech at. Set upon init.
 */
@property (readonly) NSView *view;

/**
 * Zero fps means that invalidation will cause setNeedDisplay immediately.
 */
@property unsigned fps;

/**
 * Marks view as invalid thus needs to be redrawn.
 * If fps > 0 then needsDisplay would be deferred.
 * Otherwise it is called immediately
 */
- (void) invalidate;

@end

@protocol ViewWithFPSLimitedDrawer <NSObject>

@required
@property (nonatomic, readonly) FPSLimitedDrawer *fpsDrawer;

@end
