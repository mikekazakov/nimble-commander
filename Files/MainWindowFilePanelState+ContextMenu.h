//
//  MainWindowFilePanelState+ContextMenu.h
//  Files
//
//  Created by Michael G. Kazakov on 07.11.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "MainWindowFilePanelState.h"
#import "VFS.h"

@interface MainWindowFilePanelState (ContextMenu)

- (NSMenu*) RequestContextMenuOn:(vector<VFSFlexibleListingItem>) _items
                          caller:(PanelController*) _caller;

@end
