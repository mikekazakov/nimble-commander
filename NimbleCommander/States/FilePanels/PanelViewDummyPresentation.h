// Copyright (C) 2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelViewImplementationProtocol.h"
#include "PanelDataSortMode.h"

@interface NCPanelViewDummyPresentation : NSView<NCPanelViewPresentationProtocol>

@property (nonatomic, readonly) int itemsInColumn;
@property (nonatomic, readonly) int maxNumberOfVisibleItems;
@property (nonatomic) int cursorPosition;
@property (nonatomic) nc::panel::data::SortMode sortMode;


@end
