#pragma once

#include "PanelListViewDateFormatting.h"

@interface PanelListViewDateTimeView : NSView

@property (nonatomic) time_t time;
@property (nonatomic) PanelListViewDateFormatting::Style style;

- (void) buildPresentation;


@end
