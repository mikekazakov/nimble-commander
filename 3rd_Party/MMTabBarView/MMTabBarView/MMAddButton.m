#include "MMAddButton.h"

static const double g_LongPressDelay = 0.33;

@implementation MMAddButton
{
    BOOL _long_press_scheduled;
    BOOL _long_press_fired;
}

- (void)mouseDown:(NSEvent *)event {
    if( self.longPressAction == nil ) {
        [super mouseDown:event];
        return;
    }
    _long_press_scheduled = YES;
    _long_press_fired = NO;
    [self performSelector:@selector(fireLongPress) withObject:nil afterDelay:g_LongPressDelay];
    self.highlighted = YES;
}

- (void)fireLongPress {
    if( _long_press_scheduled == NO )
        return;
 
    _long_press_scheduled = NO;
    
    if( self.longPressAction == nil || self.target == nil )
        return;
    
    _long_press_fired = YES;
    [self sendAction:self.longPressAction to:self.target];
}

- (void)mouseUp:(NSEvent *)event {
    if( self.longPressAction == nil ) {
        [super mouseDown:event];
        return;
    }
    
    self.highlighted = NO;
    if( _long_press_scheduled == YES ) {
        _long_press_scheduled = NO;
        [self sendAction:self.action to:self.target];
        return;
    }
    
    if( _long_press_fired == YES ) {
        _long_press_fired = NO;
        return;
    }
}

- (void)mouseExited:(NSEvent *)theEvent {
    _long_press_scheduled = NO;
    _long_press_fired = NO;
    self.highlighted = NO;
    [super mouseExited:theEvent];
}

@end
