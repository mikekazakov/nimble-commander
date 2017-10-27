// Copyright (C) 2017 Michael Kazakov. Subject to GNU General Public License version 3.
#pragma once

#include <VFS/VFS.h>

namespace nc::ops::copying {

class SourceItems
{
public:
    int             InsertItem(uint16_t _host_index,
                               unsigned _base_dir_index,
                               int _parent_index, string _item_name,
                               const VFSStat &_stat );
    
    uint64_t        TotalRegBytes() const noexcept;
    int             ItemsAmount() const noexcept;
    
    string          ComposeFullPath( int _item_no ) const;
    string          ComposeRelativePath( int _item_no ) const;
    const string&   ItemName( int _item_no ) const;
    mode_t          ItemMode( int _item_no ) const;
    uint64_t        ItemSize( int _item_no ) const;
    dev_t           ItemDev( int _item_no ) const; // meaningful only for native vfs (yet?)
    VFSHost        &ItemHost( int _item_no ) const;
    
    VFSHost &Host( uint16_t _host_ind ) const;
    uint16_t InsertOrFindHost( const VFSHostPtr &_host );
    
    const string &BaseDir( unsigned _base_dir_ind ) const;
    unsigned InsertOrFindBaseDir( const string &_dir );
    
    
private:
    struct SourceItem
    {
        // full path = m_SourceItemsBaseDirectories[base_dir_index] + ... +
        //             m_Items[m_Items[parent_index].parent_index].item_name +
        //             m_Items[parent_index].item_name +
        //             item_name;
        string      item_name;
        uint64_t    item_size;
        int         parent_index;
        unsigned    base_dir_index;
        uint16_t    host_index;
        uint16_t    mode;
        dev_t       dev_num;
    };
    
    vector<SourceItem>                      m_Items;
    vector<VFSHostPtr>                      m_SourceItemsHosts;
    vector<string>                          m_SourceItemsBaseDirectories;
    uint64_t                                m_TotalRegBytes = 0;
};

}
