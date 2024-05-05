// Copyright (C) 2013-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once
#import "PanelController.h"

@interface PanelController (DataAccess)

/**
 * Copies currently focused entry name.
 * Return "" if there's no focused entry (invalid state).
 */
@property(nonatomic, readonly) std::string currentFocusedEntryFilename;

/**
 * Copies currently focused item's full path relating to it's host.
 * Return "" if there's no focused entry (invalid state).
 */
@property(nonatomic, readonly) std::string currentFocusedEntryPath;

/** Copies current directory path with trailing slash relating to it's host. */
@property(nonatomic, readonly) std::string currentDirectoryPath;

/**
 * Return a list of selected entries filenames if any.
 * If no entries is selected - return currently focused element filename.
 * On case of only focused dot-dot entry return an empty list.
 */
@property(nonatomic, readonly) std::vector<std::string> selectedEntriesOrFocusedEntryFilenames;

/**
 * Like previous, but returns indeces in listing.
 * Order of items will obey current sorting.
 */
@property(nonatomic, readonly) std::vector<unsigned> selectedEntriesOrFocusedEntryIndeces;

/**
 * Return a list of selected entries filenames if any.
 * If no entries is selected - return currently focused element filename, including case of dot-dot.
 */
@property(nonatomic, readonly) std::vector<std::string> selectedEntriesOrFocusedEntryFilenamesWithDotDot;

@property(nonatomic, readonly) std::vector<VFSListingItem> selectedEntriesOrFocusedEntry;

@property(nonatomic, readonly) std::vector<VFSListingItem> selectedEntriesOrFocusedEntryWithDotDot;

/**
 * Return current (topmost in vfs stack) VFS Host.
 * If current listing is non-uniform - will throw an exception.
 */
@property(nonatomic, readonly) const std::shared_ptr<VFSHost> &vfs;

/**
 * Expands path with replacting ./ or ~/
 */
- (std::string)expandPath:(const std::string &)_ref;

@end
