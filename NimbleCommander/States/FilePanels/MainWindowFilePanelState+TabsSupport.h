#include "MainWindowFilePanelState.h"

@interface MainWindowFilePanelState (TabsSupport)

- (void) addNewTabToTabView:(NSTabView *)aTabView; // will actually call spawnNewTabInTabView
- (PanelController*)spawnNewTabInTabView:(NSTabView *)aTabView autoDirectoryLoading:(bool)_load activateNewPanel:(bool)_activate;

- (void) updateTabNameForController:(PanelController*)_controller;
- (void) closeCurrentTab;
- (void) updateTabBarsVisibility;
- (void) updateTabBarButtons;

/**
 * if file panel is not active - return 0, otherwise return amount of tabs on active side
 */
- (unsigned) currentSideTabsCount;

- (void) selectPreviousFilePanelTab;
- (void) selectNextFilePanelTab;

@end
