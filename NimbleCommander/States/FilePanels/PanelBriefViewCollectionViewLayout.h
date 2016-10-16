#pragma once

@interface PanelBriefViewCollectionViewLayout : NSCollectionViewFlowLayout

- (int) rowsCount;
- (vector<int>&) columnPositions; // may contain "empty value" - numeric_limits<int>::max()


@end
