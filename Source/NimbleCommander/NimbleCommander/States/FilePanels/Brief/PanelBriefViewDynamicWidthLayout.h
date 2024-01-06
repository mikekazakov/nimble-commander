// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelBriefViewLayoutProtocol.h"

@interface NCPanelBriefViewDynamicWidthLayout :
    NSCollectionViewFlowLayout<NCPanelBriefViewLayoutProtocol>

@property (nonatomic) int itemMinWidth;
@property (nonatomic) int itemMaxWidth;

@end 
