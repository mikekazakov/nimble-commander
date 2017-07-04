#include "PoolView.h"


@implementation NCOpsPoolView

- (void) drawRect:(NSRect)dirtyRect
{
    if( !self.window.isMainWindow )
        return;

    [NSColor.windowBackgroundColor set];
    NSRectFill(dirtyRect);
    return;
}

- (void)viewWillMoveToWindow:(NSWindow *)_wnd
{
    if( _wnd ) {
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowStatusDidChange)
                                                   name:NSWindowDidBecomeMainNotification
                                                 object:_wnd];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(windowStatusDidChange)
                                                   name:NSWindowDidResignMainNotification
                                                 object:_wnd];
    }
    else {
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:NSWindowDidBecomeMainNotification
                                                    object:nil];
        [NSNotificationCenter.defaultCenter removeObserver:self
                                                      name:NSWindowDidResignMainNotification
                                                    object:nil];
    }
}

- (void) windowStatusDidChange
{
    [self setNeedsDisplay:true];
}


@end

 
