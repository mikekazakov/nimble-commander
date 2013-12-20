//
//  VFSPath.h
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "string"
#import "vector"

using namespace std;

class VFSListing;

class VFSPathStack
{
public:
    struct Part
    {
        string fs_tag;
        /* string fs_opt; - later: params for network fs etc */
        string path;
    };
    
    static VFSPathStack CreateWithVFSListing(shared_ptr<VFSListing> _listing);
    
    
    const Part& operator[](size_t _n) const { return m_Path[_n]; }
    inline size_t size() const { return m_Path.size(); }
private:
    vector<Part> m_Path;
};
