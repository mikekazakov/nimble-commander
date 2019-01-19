// Copyright (C) 2014-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <VFS/VFS.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>

@class FindFilesSheetController;

namespace nc::panel {

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
    
struct FindFilesSheetViewRequest {
    VFSHostPtr vfs;
    std::string path;
    struct ContentMark {
        int64_t bytes_offset;
        int64_t bytes_length;
        std::string search_term;
    };
    std::optional<ContentMark> content_mark;
    FindFilesSheetController *sender;
};

}

@interface FindFilesSheetController : SheetController<NSTableViewDataSource,
                                                      NSTableViewDelegate,
                                                      NSComboBoxDataSource,
                                                      NSComboBoxDelegate>

@property (nonatomic) VFSHostPtr host;
@property (nonatomic) std::string path;
@property (nonatomic) std::function<void(const std::vector<VFSPath> &_filepaths)> onPanelize;
@property (nonatomic) std::function<void(const nc::panel::FindFilesSheetViewRequest&)> onView;
@property (nonatomic) nc::core::VFSInstanceManager *vfsInstanceManager;
- (const nc::panel::FindFilesSheetControllerFoundItem*) selectedItem; // may be nullptr

@end
