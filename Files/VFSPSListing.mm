//
//  VFSPSListing.mm
//  Files
//
//  Created by Michael G. Kazakov on 26.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#include "VFSPSListing.h"
#include "VFSPSHost.h"
#include "VFSPSInternal.h"
#include "Common.h"

VFSPSListing::VFSPSListing(const char* _relative_path,
                           shared_ptr<VFSPSHost> _host,
                           shared_ptr<VFSPSHost::Snapshot> _snapshot
                           ):
    VFSListing(_relative_path, _host),
    m_Snapshot(_snapshot)
{
    int i = 0, e = (int)_snapshot->procs.size();
    
    for(; i !=e ; ++i)
    {
        VFSPSListingItem t;
        t.index = i;
        t.data = _snapshot.get();
        t.cf_name = (CFStringRef)CFBridgingRetain([NSString stringWithUTF8StdStringNoCopy:
                                                   _snapshot->plain_filenames[i]]);
        m_Items.push_back(t);
    }
}

VFSPSListing::~VFSPSListing()
{
    for(auto &i: m_Items)
        i.Destroy();
}

VFSListingItem& VFSPSListing::At(size_t _position)
{
    assert(_position < m_Items.size());
    return m_Items[_position];
}

const VFSListingItem& VFSPSListing::At(size_t _position) const
{
    assert(_position < m_Items.size());
    return m_Items[_position];
}

int VFSPSListing::Count() const
{
    return (int)m_Items.size();
}
