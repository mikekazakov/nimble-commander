#pragma once

#include "PanelDataSortMode.h"

@interface PanelViewHeader : NSView<NSSearchFieldDelegate>

- (void) setPath:(NSString*)_path;

@property (nonatomic, readonly) NSProgressIndicator *busyIndicator;
@property (nonatomic) NSString *searchPrompt;
@property (nonatomic) int       searchMatches;
@property (nonatomic) PanelDataSortMode sortMode;
@property (nonatomic) function<void(PanelDataSortMode)> sortModeChangeCallback;

@end
