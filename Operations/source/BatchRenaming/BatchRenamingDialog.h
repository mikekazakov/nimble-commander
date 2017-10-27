// Copyright (C) 2015-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
#include <Utility/SimpleComboBoxPersistentDataSource.h>

@interface NCOpsBatchRenamingDialog : NSWindowController<NSTableViewDataSource,
                                                         NSTableViewDelegate,
                                                         NSTextFieldDelegate,
                                                         NSComboBoxDelegate>



@property (readonly) vector<string> &filenamesSource;       // full path
@property (readonly) vector<string> &filenamesDestination;
@property bool isValidRenaming;
@property (nonatomic) NCUtilSimpleComboBoxPersistentDataSource *renamePatternDataSource;
@property (nonatomic) NCUtilSimpleComboBoxPersistentDataSource *searchForDataSource;
@property (nonatomic) NCUtilSimpleComboBoxPersistentDataSource *replaceWithDataSource;

- (instancetype) initWithItems:(vector<VFSListingItem>)_items;

@end
