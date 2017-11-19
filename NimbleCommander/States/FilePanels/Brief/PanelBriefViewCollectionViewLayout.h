// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface PanelBriefViewCollectionViewLayout : NSCollectionViewFlowLayout

- (int) rowsCount;
- (const vector<int>&) columnPositions; // may contain "empty value" - numeric_limits<int>::max()
- (const vector<int>&) columnWidths; // may contain zero as a placeholder

@end
