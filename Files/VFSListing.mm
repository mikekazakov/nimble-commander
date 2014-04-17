//
//  VFSListing.cpp
//  Files
//
//  Created by Michael G. Kazakov on 25.08.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import <assert.h>
#import "VFSListing.h"
#import "Common.h"

VFSListing::VFSListing(const char* _relative_path, shared_ptr<VFSHost> _host):
    m_RelativePath(_relative_path),
    m_Host(_host)
{
    if(!IsPathWithTrailingSlash(_relative_path))
        m_RelativePath.push_back('/');
}

VFSListing::~VFSListing()
{
}

const char *VFSListing::RelativePath() const
{
    return m_RelativePath.c_str();    
}

const shared_ptr<VFSHost> &VFSListing::Host() const
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

string VFSListing::ComposeFullPathForEntry(size_t _entry_position) const
{
    if(_entry_position >= Count())
        return "";
  
    string res = RelativePath();
    const auto &entry = At(_entry_position);
    if(entry.IsDotDot())
    {
        // need to cut the last slash
        if(res != "/")
        {
            if(res.back() == '/')
                res.pop_back();
            auto i = res.rfind('/');
            if(i == 0)
                res.resize(i+1);
            else if(i != string::npos)
                res.resize(i);
        }
    }
    else
    {
        if(res.back() != '/') res += '/';
        res += entry.Name();
    }
    return res;
}
