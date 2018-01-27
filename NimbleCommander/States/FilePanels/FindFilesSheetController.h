// Copyright (C) 2014-2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <VFS/VFS.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>

struct FindFilesSheetControllerFoundItem
{
    VFSHostPtr host;
    string filename;
    string dir_path;
    string rel_path; // relative directory path
    string full_filename;
    VFSStat st;
    CFRange content_pos;
};

@interface FindFilesSheetController : SheetController<NSTableViewDataSource, NSTableViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate>

@property (nonatomic) VFSHostPtr host;
@property (nonatomic) string path;
@property (nonatomic) function<void(const vector<VFSPath> &_filepaths)> onPanelize;
@property (nonatomic) nc::core::VFSInstanceManager *vfsInstanceManager;
- (FindFilesSheetControllerFoundItem*) selectedItem; // may be nullptr

@end
