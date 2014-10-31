
#import "MainWindowFilePanelState.h"

@interface MainWindowFilePanelState (TabsSupport)

- (void) addNewTabToTabView:(NSTabView *)aTabView;
- (void) updateTabNameForController:(PanelController*)_controller;

@end