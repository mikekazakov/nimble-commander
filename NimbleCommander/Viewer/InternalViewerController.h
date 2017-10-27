// Copyright (C) 2016 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "BigFileView.h"

@interface InternalViewerController : NSResponder<NSSearchFieldDelegate>

// UI wiring
@property (nonatomic) BigFileView           *view;
@property (nonatomic) NSSearchField         *searchField;
@property (nonatomic) NSProgressIndicator   *searchProgressIndicator;
@property (nonatomic) NSPopUpButton         *encodingsPopUp;
@property (nonatomic) NSPopUpButton         *modePopUp;
@property (nonatomic) NSButton              *positionButton;
@property (nonatomic) NSTextField           *fileSizeLabel;
@property (nonatomic) NSButton              *wordWrappingCheckBox;

// Useful information
@property (nonatomic, readonly) NSString           *verboseTitle;
@property (nonatomic, readonly) const string&       filePath;
@property (nonatomic, readonly) const VFSHostPtr&   fileVFS;

- (void) setFile:(string)path at:(VFSHostPtr)vfs;
- (bool) performBackgroundOpening;

- (bool) performSyncOpening;

- (void) show;
- (void) clear;
- (void) saveFileState;

- (void)markSelection:(CFRange)_selection forSearchTerm:(string)_request;

+ (unsigned) fileWindowSize;

@end
