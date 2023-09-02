// Copyright (C) 2017-2023 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include "Options.h"
#include "DeletionJobCallbacks.h"
#include <VFS/VFS.h>
#include <Habanero/chained_strings.h>
#include <stack>

namespace nc::ops {

class DeletionJob final : public Job, public DeletionJobCallbacks
{
public:
    DeletionJob(std::vector<VFSListingItem> _items, DeletionType _type);
    ~DeletionJob();

    int ItemsInScript() const;

private:
    struct SourceItem {
        int listing_item_index;
        DeletionType type;
        const base::chained_strings::node *filename;
    };

    virtual void Perform() override;
    void DoScan();
    void DoDelete();
    void DoRmDir(const std::string &_path, VFSHost &_vfs);
    void DoUnlink(const std::string &_path, VFSHost &_vfs);
    void DoTrash(const std::string &_path, VFSHost &_vfs, SourceItem _src);
    bool DoUnlock(const std::string &_path, VFSHost &_vfs);
    void ScanDirectory(const std::string &_path,
                       int _listing_item_index,
                       const base::chained_strings::node *_prefix);
    bool IsNativeLockedItem(int vfs_err, const std::string &_path, VFSHost &_vfs) const;
    int UnlockItem(const std::string &_path, VFSHost &_vfs) const;

    std::vector<VFSListingItem> m_SourceItems;
    DeletionType m_Type;
    base::chained_strings m_Paths;
    std::stack<SourceItem> m_Script;
};

} // namespace nc::ops
