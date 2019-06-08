// Copyright (C) 2017-2019 Michael Kazakov. Subject to GNU General Public License version 3.
#include <sys/stat.h>
#include <Habanero/algo.h>
#include <Utility/PathManip.h>
#include "SourceItems.h"

namespace nc::ops::copying {

int SourceItems::InsertItem(uint16_t _host_index,
                            unsigned _base_dir_index,
                            int _parent_index,
                            std::string _item_name,
                            const VFSStat &_stat )
{
    if( _host_index >= m_SourceItemsHosts.size() ||
       _base_dir_index >= m_SourceItemsBaseDirectories.size() ||
       (_parent_index >= 0 && _parent_index >= (int)m_Items.size() ) )
        throw std::invalid_argument("SourceItems::InsertItem: invalid index");
    
    if( S_ISREG(_stat.mode) )
        m_TotalRegBytes += _stat.size;
    
    SourceItem it;
    it.item_name = S_ISDIR(_stat.mode) ? EnsureTrailingSlash( move(_item_name) ) : move( _item_name );
    it.parent_index = _parent_index;
    it.base_dir_index = _base_dir_index;
    it.host_index = _host_index;
    it.mode = _stat.mode;
    it.dev_num = _stat.dev;
    it.item_size = _stat.size;
    
    m_Items.emplace_back( std::move(it) );
    
    return int(m_Items.size() - 1);
}

std::string SourceItems::ComposeFullPath( int _item_no ) const
{
    auto rel_path = ComposeRelativePath( _item_no );
    rel_path.insert(0, m_SourceItemsBaseDirectories[ m_Items[_item_no].base_dir_index] );
    return rel_path;
}

std::string SourceItems::ComposeRelativePath( int _item_no ) const
{
    auto &meta = m_Items.at(_item_no);
    std::array<int, 128> parents;
    int parents_num = 0;
    
    int parent = meta.parent_index;
    while( parent >= 0 ) {
        parents[parents_num++] = parent;
        parent = m_Items[parent].parent_index;
    }
    
    std::string path;
    for( int i = parents_num - 1; i >= 0; i-- )
        path += m_Items[ parents[i] ].item_name;
    
    path += meta.item_name;
    
    if( !path.empty() && path.back() == '/' )
        path.pop_back();
    
    return path;
}

int SourceItems::ItemsAmount() const noexcept
{
    return (int)m_Items.size();
}

uint64_t SourceItems::TotalRegBytes() const noexcept
{
    return m_TotalRegBytes;
}

mode_t SourceItems::ItemMode( int _item_no ) const
{
    return m_Items.at(_item_no).mode;
}

uint64_t SourceItems::ItemSize( int _item_no ) const
{
    return m_Items.at(_item_no).item_size;
}

const std::string& SourceItems::ItemName( int _item_no ) const
{
    return m_Items.at(_item_no).item_name;
}

dev_t SourceItems::ItemDev( int _item_no ) const
{
    return m_Items.at(_item_no).dev_num;
}

VFSHost &SourceItems::ItemHost( int _item_no ) const
{
    return *m_SourceItemsHosts[ m_Items.at(_item_no).host_index ];
}

uint16_t SourceItems::InsertOrFindHost( const VFSHostPtr &_host )
{
    return (uint16_t)linear_find_or_insert(m_SourceItemsHosts, _host);
}

unsigned SourceItems::InsertOrFindBaseDir( const std::string &_dir )
{
    return (unsigned)linear_find_or_insert(m_SourceItemsBaseDirectories, _dir);
}

const std::string &SourceItems::BaseDir( unsigned _ind ) const
{
    return m_SourceItemsBaseDirectories.at(_ind);
}

VFSHost &SourceItems::Host( uint16_t _ind ) const
{
    return *m_SourceItemsHosts.at(_ind);
}

}
