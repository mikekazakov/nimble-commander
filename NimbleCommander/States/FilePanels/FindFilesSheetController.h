// Copyright (C) 2014-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <VFS/VFS.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>

struct FindFilesSheetControllerFoundItem
{
    VFSHostPtr host;
    std::string filename;
    std::string dir_path;
    std::string rel_path; // relative directory path
    std::string full_filename;
    VFSStat st;
    CFRange content_pos;
};

@interface FindFilesSheetController : SheetController<NSTableViewDataSource, NSTableViewDelegate, NSComboBoxDataSource, NSComboBoxDelegate>

@property (nonatomic) VFSHostPtr host;
@property (nonatomic) std::string path;
@property (nonatomic) std::function<void(const std::vector<VFSPath> &_filepaths)> onPanelize;
@property (nonatomic) nc::core::VFSInstanceManager *vfsInstanceManager;
- (FindFilesSheetControllerFoundItem*) selectedItem; // may be nullptr

@end
