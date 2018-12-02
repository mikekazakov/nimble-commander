// Copyright (C) 2015-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Cocoa/Cocoa.h>
#include <VFS/VFS.h>
#include <Utility/SimpleComboBoxPersistentDataSource.h>

@interface NCOpsBatchRenamingDialog : NSWindowController<NSTableViewDataSource,
                                                         NSTableViewDelegate,
                                                         NSTextFieldDelegate,
                                                         NSComboBoxDelegate>



@property (readonly) std::vector<std::string> &filenamesSource;       // full path
@property (readonly) std::vector<std::string> &filenamesDestination;
@property bool isValidRenaming;
@property (nonatomic) NCUtilSimpleComboBoxPersistentDataSource *renamePatternDataSource;
@property (nonatomic) NCUtilSimpleComboBoxPersistentDataSource *searchForDataSource;
@property (nonatomic) NCUtilSimpleComboBoxPersistentDataSource *replaceWithDataSource;

- (instancetype) initWithItems:(std::vector<VFSListingItem>)_items;

@end
