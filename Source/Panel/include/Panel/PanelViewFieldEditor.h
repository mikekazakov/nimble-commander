// Copyright (C) 2017-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>
#include <Cocoa/Cocoa.h>

@interface NCPanelViewFieldEditor : NSScrollView <NSTextViewDelegate>

- (instancetype)initWithItem:(VFSListingItem)_item;
- (void)markNextFilenamePart;

// Notifies the field editor that it will be temporarily removed from the view hierarchy upon data updating.
// Thus the field editor should not trigger .onEditingFinished upon removal fround the hierarchy.
// It will likely be put back into the view hierarchy afterwards.
- (void)stash;

// Reverts the effect of the stashing operation.
- (void)unstash;

@property(nonatomic, readonly) NSTextView *editor;
@property(nonatomic, readonly) VFSListingItem originalItem;
@property(nonatomic) void (^onTextEntered)(const std::string &_new_filename);
@property(nonatomic) void (^onEditingFinished)();

@end
