#pragma once

#include <Cocoa/Cocoa.h>

@class PanelView;

namespace nc::panel::view::BiddingPriority {

constexpr int Skip      = 0;
constexpr int Low       = 10;
constexpr int Default   = 100;
constexpr int High      = 1000;

}

@protocol NCPanelViewKeystrokeSink <NSObject>
@required

/**
 * Return a positive value to participate in bidding.
 */
- (int)bidForHandlingKeyDown:(NSEvent *)_event forPanelView:(PanelView*)_panel_view;

/**
 * Do an actual keystroke processing.
 */
- (void)handleKeyDown:(NSEvent *)_event forPanelView:(PanelView*)_panel_view;

@end
