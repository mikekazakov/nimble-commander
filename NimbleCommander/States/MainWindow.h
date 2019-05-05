// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCMainWindow : NSWindow

- (instancetype) init;
+ (NSString*) defaultIdentifier;
+ (NSString*) defaultFrameIdentifier;

@end
