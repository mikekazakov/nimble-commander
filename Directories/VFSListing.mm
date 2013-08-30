//
//  VFSListing.cpp
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSListing.h"
#import <assert.h>

VFSListing::VFSListing(const char* _relative_path, std::shared_ptr<VFSHost> _host):
    m_RelativePath(_relative_path),
    m_Host(_host)
{
}

VFSListing::~VFSListing()
{
}

const char *VFSListing::RelativePath() const
{
    return m_RelativePath.c_str();    
}

std::shared_ptr<VFSHost> VFSListing::Host() const
{
    return m_Host;
}

VFSListingItem& VFSListing::At(size_t _position)
{
    assert(0);
    static VFSListingItem i;
    return i;
}

const VFSListingItem& VFSListing::At(size_t _position) const
{
    assert(0);
    static VFSListingItem i;
    return i;
}

int VFSListing::Count() const
{
    return 0;
}

long VFSListing::Attributes() const
{
    return 0;
}