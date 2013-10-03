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

void VFSListing::ComposeFullPathForEntry(size_t _entry_position, char *_buf) const
{
    if(_entry_position >= Count())
    {
        strcpy(_buf, "");
        return;
    }
  
    const auto &entry = At(_entry_position);
    
    if(entry.IsDotDot())
    {
        // need to cut the last slash
        strcpy(_buf, RelativePath());
        if(strcmp(_buf, "/") != 0)
        {
            if(_buf[strlen(_buf)-1] == '/') _buf[strlen(_buf)-1] = 0; // cut trailing slash
            char *s = strrchr(_buf, '/');
            if(s != _buf) *s = 0;
            else *(s+1) = 0;
        }
    }
    else
    {
        strcpy(_buf, RelativePath());
        if(_buf[strlen(_buf)-1] != '/') strcat(_buf, "/");
        strcat(_buf, entry.Name());
    }
}