// Copyright (C) 2014-2025 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>

@interface NCMainWindow : NSWindow <NSMenuItemValidation>

- (instancetype)init;
+ (NSString *)defaultIdentifier;
+ (NSString *)defaultFrameIdentifier;

@end
