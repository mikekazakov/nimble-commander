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
