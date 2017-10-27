// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

@interface PanelBriefViewCollectionViewLayout : NSCollectionViewFlowLayout

- (int) rowsCount;
- (vector<int>&) columnPositions; // may contain "empty value" - numeric_limits<int>::max()


@end
