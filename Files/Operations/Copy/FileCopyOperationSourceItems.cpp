//
//  FileCopyOperationSourceItems.cpp
//  Files
//
//  Created by Michael G. Kazakov on 07/10/15.
//  Copyright © 2015 Michael G. Kazakov. All rights reserved.
//

#include <Habanero/algo.h>
#include "Common.h"
#include "VFS.h"
#include "FileCopyOperationJobNew.h"

int FileCopyOperationJobNew::SourceItems::InsertItem( uint16_t _host_index, unsigned _base_dir_index, int _parent_index, string _item_name, const VFSStat &_stat )
{
    if( _host_index >= m_SourceItemsHosts.size() ||
       _base_dir_index >= m_SourceItemsBaseDirectories.size() ||
       (_parent_index >= 0 && _parent_index >= m_Items.size() ) )
        throw invalid_argument("FileCopyOperationJobNew::SourceItems::InsertItem: invalid index");
    
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
    
    m_Items.emplace_back( move(it) );
    
    return int(m_Items.size() - 1);
}

string FileCopyOperationJobNew::SourceItems::ComposeFullPath( int _item_no ) const
{
    auto rel_path = ComposeRelativePath( _item_no );
    rel_path.insert(0, m_SourceItemsBaseDirectories[ m_Items[_item_no].base_dir_index] );
    return rel_path;
}

string FileCopyOperationJobNew::SourceItems::ComposeRelativePath( int _item_no ) const
{
    auto &meta = m_Items.at(_item_no);
    array<int, 128> parents;
    int parents_num = 0;
    
    int parent = meta.parent_index;
    while( parent >= 0 ) {
        parents[parents_num++] = parent;
        parent = m_Items[parent].parent_index;
    }
    
    string path;
    for( int i = parents_num - 1; i >= 0; i-- )
        path += m_Items[ parents[i] ].item_name;
    
    path += meta.item_name;
    return path;
}

int FileCopyOperationJobNew::SourceItems::ItemsAmount() const noexcept
{
    return (int)m_Items.size();
}

uint64_t FileCopyOperationJobNew::SourceItems::TotalRegBytes() const noexcept
{
    return m_TotalRegBytes;
}

mode_t FileCopyOperationJobNew::SourceItems::ItemMode( int _item_no ) const
{
    return m_Items.at(_item_no).mode;
}

uint64_t FileCopyOperationJobNew::SourceItems::ItemSize( int _item_no ) const
{
    return m_Items.at(_item_no).item_size;
}

const string& FileCopyOperationJobNew::SourceItems::ItemName( int _item_no ) const
{
    return m_Items.at(_item_no).item_name;
}

dev_t FileCopyOperationJobNew::SourceItems::ItemDev( int _item_no ) const
{
    return m_Items.at(_item_no).dev_num;
}

VFSHost &FileCopyOperationJobNew::SourceItems::ItemHost( int _item_no ) const
{
    return *m_SourceItemsHosts[ m_Items.at(_item_no).host_index ];
}

uint16_t FileCopyOperationJobNew::SourceItems::InsertOrFindHost( const VFSHostPtr &_host )
{
    return (uint16_t)linear_find_or_insert(m_SourceItemsHosts, _host);
}

unsigned FileCopyOperationJobNew::SourceItems::InsertOrFindBaseDir( const string &_dir )
{
    return (unsigned)linear_find_or_insert(m_SourceItemsBaseDirectories, _dir);
}

const string &FileCopyOperationJobNew::SourceItems::BaseDir( unsigned _ind ) const
{
    return m_SourceItemsBaseDirectories.at(_ind);
}

VFSHost &FileCopyOperationJobNew::SourceItems::Host( uint16_t _ind ) const
{
    return *m_SourceItemsHosts.at(_ind);
}