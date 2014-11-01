
#import "MainWindowFilePanelState.h"

@interface MainWindowFilePanelState (TabsSupport)

- (void) addNewTabToTabView:(NSTabView *)aTabView;
- (void) updateTabNameForController:(PanelController*)_controller;
- (void) closeCurrentTab;

/**
 * if file panel is not active - return 0, otherwise return amount of tabs on active side
 */
- (unsigned) currentSideTabsCount;

- (void) selectPreviousFilePanelTab;
- (void) selectNextFilePanelTab;

@end