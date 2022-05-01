// Copyright (C) 2014-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <functional>
#include <Panel/FindFilesData.h>

@interface SelectionWithMaskPopupViewController : NSViewController <NSPopoverDelegate, NSSearchFieldDelegate>

- (instancetype)initInitialQuery:(const nc::panel::FindFilesMask &)_initial_mask
                         history:(std::span<const nc::panel::FindFilesMask>)_masks
                      doesSelect:(bool)_select;

@property(nonatomic) std::function<void(const nc::panel::FindFilesMask &_mask)> onSelect;

@property(nonatomic) std::function<void()> onClearHistory;

@end
