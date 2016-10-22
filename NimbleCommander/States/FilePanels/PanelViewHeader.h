#pragma once

@interface PanelViewHeader : NSView<NSSearchFieldDelegate>

- (void) setPath:(NSString*)_path;

@property (nonatomic) NSString *searchPrompt;
@property (nonatomic) int       searchMatches;

@end
