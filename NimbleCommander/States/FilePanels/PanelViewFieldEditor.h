// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

@interface NCPanelViewFieldEditor : NSScrollView<NSTextViewDelegate>

- (instancetype)initWithItem:(VFSListingItem)_item;
- (void)markNextFilenamePart;

@property (nonatomic, readonly) NSTextView *textView;
@property (nonatomic, readonly) VFSListingItem originalItem;
@property (nonatomic) void (^onTextEntered)(const string &_new_filename);
@property (nonatomic) void (^onEditingFinished)();

@end
