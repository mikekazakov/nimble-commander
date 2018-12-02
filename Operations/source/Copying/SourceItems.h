// Copyright (C) 2017-2018 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::ops::copying {

class SourceItems
{
public:
    int             InsertItem(uint16_t _host_index,
                               unsigned _base_dir_index,
                               int _parent_index,
                               std::string _item_name,
                               const VFSStat &_stat );
    
    uint64_t        TotalRegBytes() const noexcept;
    int             ItemsAmount() const noexcept;
    
    std::string     ComposeFullPath( int _item_no ) const;
    std::string     ComposeRelativePath( int _item_no ) const;
    const std::string& ItemName( int _item_no ) const;
    mode_t          ItemMode( int _item_no ) const;
    uint64_t        ItemSize( int _item_no ) const;
    dev_t           ItemDev( int _item_no ) const; // meaningful only for native vfs (yet?)
    VFSHost        &ItemHost( int _item_no ) const;
    
    VFSHost &Host( uint16_t _host_ind ) const;
    uint16_t InsertOrFindHost( const VFSHostPtr &_host );
    
    const std::string &BaseDir( unsigned _base_dir_ind ) const;
    unsigned InsertOrFindBaseDir( const std::string &_dir );
    
    
private:
    struct SourceItem
    {
        // full path = m_SourceItemsBaseDirectories[base_dir_index] + ... +
        //             m_Items[m_Items[parent_index].parent_index].item_name +
        //             m_Items[parent_index].item_name +
        //             item_name;
        std::string      item_name;
        uint64_t    item_size;
        int         parent_index;
        unsigned    base_dir_index;
        uint16_t    host_index;
        uint16_t    mode;
        dev_t       dev_num;
    };
    
    std::vector<SourceItem>                 m_Items;
    std::vector<VFSHostPtr>                 m_SourceItemsHosts;
    std::vector<std::string>                m_SourceItemsBaseDirectories;
    uint64_t                                m_TotalRegBytes = 0;
};

}
