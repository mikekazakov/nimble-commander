#pragma once

#include "PanelDataSortMode.h"

@interface PanelViewHeader : NSView<NSSearchFieldDelegate>

- (void) setPath:(NSString*)_path;

@property (nonatomic, readonly) NSProgressIndicator *busyIndicator;
@property (nonatomic) NSString *searchPrompt;
@property (nonatomic) int       searchMatches;
@property (nonatomic) nc::panel::data::SortMode sortMode;
@property (nonatomic) function<void(nc::panel::data::SortMode)> sortModeChangeCallback;

@end
