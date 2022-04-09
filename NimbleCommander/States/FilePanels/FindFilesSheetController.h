// Copyright (C) 2014-2022 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <Utility/SheetController.h>
#include <VFS/VFS.h>
#include <NimbleCommander/Core/VFSInstanceManager.h>
#include <vector>
#include <span>

@class FindFilesSheetController;

namespace nc::bootstrap {
class ActivationManager;
}

namespace nc::config {
class Config;
}

namespace nc::panel {

struct FindFilesSheetControllerFoundItem {
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

struct FindFilesMask {
    enum Type
    {
        Classic = 0,
        RegEx = 1
    };
    std::string string;
    Type type = Classic;
    friend bool operator==(const FindFilesMask &lhs, const FindFilesMask &rhs) noexcept;
    friend bool operator!=(const FindFilesMask &lhs, const FindFilesMask &rhs) noexcept;
};

std::vector<FindFilesMask> LoadFindFilesMasks(const nc::config::Config &_source, std::string_view _path);
void StoreFindFilesMasks(nc::config::Config &_dest, std::string_view _path, std::span<const FindFilesMask> _masks);

}

@interface FindFilesSheetController
    : SheetController <NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithActivationManager:(nc::bootstrap::ActivationManager &)_am;

@property(nonatomic) VFSHostPtr host;
@property(nonatomic) std::string path;
@property(nonatomic) std::function<void(const std::vector<nc::vfs::VFSPath> &_filepaths)> onPanelize;
@property(nonatomic) std::function<void(const nc::panel::FindFilesSheetViewRequest &)> onView;
@property(nonatomic) nc::core::VFSInstanceManager *vfsInstanceManager;
- (const nc::panel::FindFilesSheetControllerFoundItem *)selectedItem; // may be nullptr

@end
