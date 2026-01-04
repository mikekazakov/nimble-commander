// Copyright (C) 2017-2026 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include "Options.h"
#include "DeletionJobCallbacks.h"
#include <VFS/VFS.h>
#include <Base/chained_strings.h>
#include <stack>
#include <string_view>

namespace nc::ops {

class DeletionJob final : public Job, public DeletionJobCallbacks
{
public:
    DeletionJob(std::vector<VFSListingItem> _items, DeletionType _type);
    ~DeletionJob() override;

    int ItemsInScript() const;

private:
    struct SourceItem {
        int listing_item_index;
        DeletionType type;
        const base::chained_strings::node *filename;
    };

    void Perform() override;
    void DoScan();
    void DoDelete();
    void DoRmDir(const std::string &_path, VFSHost &_vfs);
    void DoUnlink(const std::string &_path, VFSHost &_vfs);
    void DoTrash(const std::string &_path, VFSHost &_vfs, SourceItem _src);
    bool DoUnlock(const std::string &_path, VFSHost &_vfs);
    void ScanDirectory(const std::string &_path, int _listing_item_index, const base::chained_strings::node *_prefix);
    static bool IsNativeLockedItem(const nc::Error &_err, const std::string &_path, VFSHost &_vfs);
    static std::expected<void, Error> UnlockItem(std::string_view _path, VFSHost &_vfs);
    static bool
    IsEAStorage(VFSHost &_host, std::string_view _directory, std::string_view _filename, uint8_t _unix_type);

    std::vector<VFSListingItem> m_SourceItems;
    DeletionType m_Type;
    base::chained_strings m_Paths;
    std::stack<SourceItem> m_Script;
};

} // namespace nc::ops
