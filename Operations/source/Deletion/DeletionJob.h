// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include "../Job.h"
#include "Options.h"
#include <VFS/VFS.h>
#include <Habanero/chained_strings.h>

namespace nc::ops {

struct DeletionJobCallbacks
{
    enum class ReadDirErrorResolution { Stop, Skip, Retry };
    std::function< ReadDirErrorResolution(int _err, const std::string &_path, VFSHost &_vfs) >
    m_OnReadDirError =
    [](int _err, const std::string &_path, VFSHost &_vfs){ return ReadDirErrorResolution::Stop; };

    enum class UnlinkErrorResolution { Stop, Skip, Retry };
    std::function< UnlinkErrorResolution(int _err, const std::string &_path, VFSHost &_vfs) >
    m_OnUnlinkError =
    [](int _err, const std::string &_path, VFSHost &_vfs){ return UnlinkErrorResolution::Stop; };

    enum class RmdirErrorResolution { Stop, Skip, Retry };
    std::function< RmdirErrorResolution(int _err, const std::string &_path, VFSHost &_vfs) >
    m_OnRmdirError =
    [](int _err, const std::string &_path, VFSHost &_vfs){ return RmdirErrorResolution::Stop; };

    enum class TrashErrorResolution { Stop, Skip, DeletePermanently, Retry };
    std::function< TrashErrorResolution(int _err, const std::string &_path, VFSHost &_vfs) >
    m_OnTrashError =
    [](int _err, const std::string &_path, VFSHost &_vfs){ return TrashErrorResolution::Stop; };
};

class DeletionJob final : public Job, public DeletionJobCallbacks
{
public:
    DeletionJob( std::vector<VFSListingItem> _items, DeletionType _type );
    ~DeletionJob();
    
    int ItemsInScript() const;
    
private:
    struct SourceItem
    {
        int listing_item_index;
        DeletionType type;
        const chained_strings::node *filename;
    };

    virtual void Perform() override;
    void DoScan();
    void DoDelete();
    void DoRmDir( const std::string &_path, VFSHost &_vfs );
    void DoUnlink( const std::string &_path, VFSHost &_vfs );
    void DoTrash( const std::string &_path, VFSHost &_vfs, SourceItem _src );
    void ScanDirectory(const std::string &_path,
                       int _listing_item_index,
                       const chained_strings::node *_prefix);
    
    std::vector<VFSListingItem>  m_SourceItems;
    DeletionType            m_Type;
    chained_strings         m_Paths;
    std::stack<SourceItem>  m_Script;
};

}
