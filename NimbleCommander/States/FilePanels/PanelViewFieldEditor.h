// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Cocoa/Cocoa.h>

@interface NCPanelViewFieldEditor : NSScrollView<NSTextViewDelegate>

- (instancetype)initWithItem:(VFSListingItem)_item;
- (void)markNextFilenamePart;

@property (nonatomic, readonly) NSTextView *editor;
@property (nonatomic, readonly) VFSListingItem originalItem;
@property (nonatomic) void (^onTextEntered)(const std::string &_new_filename);
@property (nonatomic) void (^onEditingFinished)();

@end
