#pragma once

#include <Cocoa/Cocoa.h>

@class PanelView;

namespace nc::panel::view::BiddingPriority {

constexpr int Skip = 0;
constexpr int Low = 25;
constexpr int Default = 50;
constexpr int High = 75;
constexpr int Max = 100;

} // namespace nc::panel::view::BiddingPriority

@protocol NCPanelViewKeystrokeSink <NSObject>
@required

/**
 * Return a positive value to participate in bidding.
 */
- (int)bidForHandlingKeyDown:(NSEvent *)_event forPanelView:(PanelView *)_panel_view;

/**
 * Do an actual keystroke processing.
 */
- (void)handleKeyDown:(NSEvent *)_event forPanelView:(PanelView *)_panel_view;

@end
