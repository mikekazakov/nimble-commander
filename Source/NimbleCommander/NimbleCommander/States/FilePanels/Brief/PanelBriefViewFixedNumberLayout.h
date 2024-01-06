// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelBriefViewLayoutProtocol.h"

@interface NCPanelBriefViewFixedNumberLayout :
    NSCollectionViewFlowLayout<NCPanelBriefViewLayoutProtocol>

@property (nonatomic) int columnsPerScreen;

@end 
