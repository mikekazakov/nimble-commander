// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface TrialWindowController : NSWindowController<NSWindowDelegate>

@property (nonatomic) std::function<void()> onBuyLicense;

- (void) show;

@end
