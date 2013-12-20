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
 * Return false if there's no focused entry (invalid state).
 */
- (bool) GetCurrentFocusedEntryFilename:(char*) _filename;

/**
 * Copies currently focused item's full path relating to it's host.
 * Return false if there's no focused entry (invalid state).
 */
- (bool) GetCurrentFocusedEntryFilePathRelativeToHost:(char*) _file_path;

/**
 * Copies directory path with trailing slash relating to it's host.
 */
- (bool) GetCurrentDirectoryPathRelativeToHost:(char*) _path;

/**
 * Return a list of selected entries if any.
 * If no entries is selected - return currently selected element if it is not dot-dot.
 * If it is dot-dot returns 0.
 * Caller is responsible for deallocation returned value.
 */
- (FlexChainedStringsChunk*) GetSelectedEntriesOrFocusedEntryWithoutDotDot;

/**
 * Return current (topmost in vfs stack) VFS Host.
 */
- (shared_ptr<VFSHost>) GetCurrentVFSHost;

@end
