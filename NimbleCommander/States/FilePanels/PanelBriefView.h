#pragma once

class PanelData;
@class PanelView;

@interface PanelBriefView : NSView<NSCollectionViewDelegate, NSCollectionViewDataSource, NSCollectionViewDelegateFlowLayout>

//- (id)initWithFrame:(NSRect)frameRect andData:(PanelData&)_data;


- (void) dataChanged;
- (void) syncVolatileData;
- (void) setData:(PanelData*)_data;

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic) int cursorPosition;

@end
