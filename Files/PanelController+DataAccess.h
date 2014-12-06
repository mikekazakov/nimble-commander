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

/** Copies current directory path with trailing slash relating to it's host. */
@property (nonatomic, readonly) string currentDirectoryPath;

/**
 * Return a list of selected entries if any.
 * If no entries is selected - return currently selected element if it is not dot-dot.
 * If it is dot-dot returns 0.
 */
- (chained_strings) GetSelectedEntriesOrFocusedEntryWithoutDotDot DEPRECATED_ATTRIBUTE;

/**
 * Return a list of selected entries if any.
 * If no entries is selected - return currently selected element.
 */
- (chained_strings) GetSelectedEntriesOrFocusedEntryWithDotDot DEPRECATED_ATTRIBUTE;

/**
 * Return a list of selected entries filenames if any.
 * If no entries is selected - return currently focused element filename.
 * On case of only focused dot-dot entry return an empty list.
 */
@property (nonatomic, readonly) vector<string> selectedEntriesOrFocusedEntryFilenames;

/**
 * Return current (topmost in vfs stack) VFS Host.
 */
- (const shared_ptr<VFSHost>&) VFS;

@end
