// Copyright (C) 2016-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface SpotlightSearchPopupViewController : NSViewController<NSPopoverDelegate>

@property (nonatomic) std::function<void(const std::string&)> handler;

@end
