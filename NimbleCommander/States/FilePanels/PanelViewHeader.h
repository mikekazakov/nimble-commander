#pragma once

#include "PanelDataSortMode.h"

@interface PanelViewHeader : NSView<NSSearchFieldDelegate>

- (void) setPath:(NSString*)_path;

@property (nonatomic) NSString *searchPrompt;
@property (nonatomic) int       searchMatches;
@property (nonatomic) PanelDataSortMode sortMode;

@end
