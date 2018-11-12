// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelBriefViewLayoutProtocol.h"

@interface NCPanelBriefViewFixedWidthLayout :
    NSCollectionViewFlowLayout<NCPanelBriefViewLayoutProtocol>

@property (nonatomic) int itemWidth;

@end 
