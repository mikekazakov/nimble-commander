//
//  VFSArchiveUnRARListing.cpp
//  Files
//
//  Created by Michael G. Kazakov on 04.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "VFSArchiveUnRARListing.h"

VFSArchiveUnRARListing::VFSArchiveUnRARListing(const VFSArchiveUnRARDirectory &_dir,
                                               const char *_path,
                                               int _flags,
                                               shared_ptr<VFSHost> _host):
    VFSListing(_path, _host)
{
    size_t shift = (_flags & VFSFlags::F_NoDotDot) ? 0 : 1;
    size_t i = 0, e = _dir.entries.size();
    m_Items.resize(_dir.entries.size() + shift);
    for(;i!=e;++i)
    {
        auto &source = _dir.entries[i];
        auto &dest = m_Items[i + shift];

        dest.m_Name = source.name.c_str();
        dest.m_NameLen = source.name.length();
        dest.m_CFName = source.cfname;
        dest.m_Size = source.isdir ? VFSListingItem::InvalidSize : source.unpacked_size;
        dest.m_ATime = source.time;
        dest.m_MTime = source.time;
        dest.m_CTime = source.time;
        dest.m_BTime = source.time;
        dest.m_Mode = S_IRUSR | S_IWUSR | (source.isdir ? S_IFDIR : 0);
        dest.m_Type = source.isdir ? DT_DIR : DT_REG;
        dest.FindExtension();        
    }
    
    if(shift)
    {
        auto &dest = m_Items[0];
        dest.m_Name = "..";
        dest.m_NameLen = 2;
        dest.m_Mode = S_IRUSR | S_IWUSR | S_IFDIR;
        dest.m_CFName = CFSTR("..");
        dest.m_Size = VFSListingItem::InvalidSize;
        dest.m_ATime = _dir.time;
        dest.m_MTime = _dir.time;
        dest.m_CTime = _dir.time;
        dest.m_BTime = _dir.time;
    }
}
