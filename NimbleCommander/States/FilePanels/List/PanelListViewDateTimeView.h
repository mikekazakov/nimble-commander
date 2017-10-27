// Copyright (C) 2016-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "PanelListViewDateFormatting.h"

@interface PanelListViewDateTimeView : NSView

@property (nonatomic) time_t time;
@property (nonatomic) PanelListViewDateFormatting::Style style;

- (void) buildPresentation;

@end
