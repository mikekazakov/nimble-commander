#import "MainWindowFilePanelState.h"

class VFSListingItem;

@interface MainWindowFilePanelState (ContextMenu)

- (NSMenu*) RequestContextMenuOn:(vector<VFSListingItem>) _items
                          caller:(PanelController*) _caller;

@end
