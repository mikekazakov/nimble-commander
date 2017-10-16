#pragma once

#include <Cocoa/Cocoa.h>

@interface NCTermFlippableHolder : NSView

- (id)initWithFrame:(NSRect)frameRect andView:(NSView*)view beFlipped:(bool)flipped;

@end
