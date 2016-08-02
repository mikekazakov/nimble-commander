//
//  FindFileSheetController.h
//  Files
//
//  Created by Michael G. Kazakov on 12.02.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <Utility/SheetController.h>
#include "../../Files/vfs/VFS.h"

struct FindFilesSheetControllerFoundItem
{
    string filename;
    string dir_path;
    string rel_path;
    string full_filename;
    VFSStat st;
    CFRange content_pos;
};

@interface FindFilesSheetController : SheetController<NSTableViewDataSource, NSTableViewDelegate, NSComboBoxDataSource>

@property (nonatomic) VFSHostPtr host;
@property (nonatomic) string path;
@property function<void(const map<string, vector<string>>&_dir_to_filenames)> onPanelize;
- (FindFilesSheetControllerFoundItem*) selectedItem; // may be nullptr

@end
