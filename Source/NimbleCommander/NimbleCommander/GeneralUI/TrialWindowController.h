// Copyright (C) 2014-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <functional>

@interface TrialWindowController : NSWindowController<NSWindowDelegate>

@property (nonatomic) bool isExpired;
@property (nonatomic) std::function<bool()> onActivate;
@property (nonatomic) std::function<void()> onBuyLicense;
@property (nonatomic) std::function<void()> onQuit;
- (void) show;

@end
