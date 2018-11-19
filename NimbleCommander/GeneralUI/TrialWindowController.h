// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface TrialWindowController : NSWindowController<NSWindowDelegate>

@property (nonatomic) bool isExpired;
@property (nonatomic) std::function<void()> onBuyLicense;
@property (nonatomic) std::function<void()> onQuit;
- (void) show;

@end
