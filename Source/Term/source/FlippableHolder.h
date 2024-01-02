// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCTermFlippableHolder : NSView

- (id)initWithFrame:(NSRect)frameRect andView:(NSView*)view beFlipped:(bool)flipped;

@end
