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
