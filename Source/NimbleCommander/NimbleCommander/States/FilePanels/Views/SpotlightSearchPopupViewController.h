// Copyright (C) 2016-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#include <functional>

@interface SpotlightSearchPopupViewController : NSViewController <NSPopoverDelegate>

@property(nonatomic) std::function<void(const std::string &)> handler;

@end
