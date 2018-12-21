// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <vector>
#include <Cocoa/Cocoa.h>

@protocol NCPanelBriefViewLayoutDelegate<NSObject>

@optional 
- (void)collectionViewDidLayoutItems:(NSCollectionView *)collectionView;

// this breaks abstraction a bit, since this part only relates to the "DynamicWidth" layout
- (std::vector<short>&)collectionViewProvideIntrinsicItemsWidths:(NSCollectionView *)collectionView;

@end

@protocol NCPanelBriefViewLayoutProtocol<NSObject>

@property (nonatomic) int itemHeight;
@property (nonatomic, weak ) id<NCPanelBriefViewLayoutDelegate> layoutDelegate;

- (int) rowsNumber;
- (int) columnsNumber;
- (const std::vector<int>&) columnsPositions;
- (const std::vector<int>&) columnsWidths;

@end
