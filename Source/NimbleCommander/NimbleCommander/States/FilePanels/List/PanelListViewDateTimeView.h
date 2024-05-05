// Copyright (C) 2016-2020 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/AdaptiveDateFormatting.h>

@interface PanelListViewDateTimeView : NSView

@property(nonatomic) time_t time;
@property(nonatomic) nc::utility::AdaptiveDateFormatting::Style style;

- (void)buildPresentation;
- (void)dateChanged;

@end
