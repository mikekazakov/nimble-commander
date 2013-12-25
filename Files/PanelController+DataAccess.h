//
//  PanelController+DataAccess.h
//  Files
//
//  Created by Michael G. Kazakov on 22.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "PanelController.h"

@interface PanelController (DataAccess)

/**
 * Copies currently focused entry name.
 * Return "" if there's no focused entry (invalid state).
 */
- (string) GetCurrentFocusedEntryFilename;

/**
 * Copies currently focused item's full path relating to it's host.
 * Return "" if there's no focused entry (invalid state).
 */
- (string) GetCurrentFocusedEntryFilePathRelativeToHost;

/**
 * Copies directory path with trailing slash relating to it's host.
 */
- (string) GetCurrentDirectoryPathRelativeToHost;

/**
 * Return a list of selected entries if any.
 * If no entries is selected - return currently selected element if it is not dot-dot.
 * If it is dot-dot returns 0.
 * Caller is responsible for deallocation returned value.
 */
- (chained_strings) GetSelectedEntriesOrFocusedEntryWithoutDotDot;

/**
 * Return current (topmost in vfs stack) VFS Host.
 */
- (shared_ptr<VFSHost>) GetCurrentVFSHost;

@end
