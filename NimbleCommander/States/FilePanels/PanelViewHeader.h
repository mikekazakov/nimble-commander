#pragma once

@interface PanelViewHeader : NSView

- (void) setPath:(NSString*)_path;

@property (nonatomic) NSString *searchPrompt;
@property (nonatomic) int       searchMatches;

@end
