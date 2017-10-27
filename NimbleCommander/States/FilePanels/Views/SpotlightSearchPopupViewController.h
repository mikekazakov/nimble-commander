// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface SpotlightSearchPopupViewController : NSViewController<NSPopoverDelegate>

@property (nonatomic) function<void(const string&)> handler;

@end
