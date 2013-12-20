//
//  VFSPath.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFSPath.h"
#import "VFSListing.h"
#import "VFSHost.h"

VFSPathStack VFSPathStack::CreateWithVFSListing(shared_ptr<VFSListing> _listing)
{
    // 1st - calculate host's depth
    int depth = 0;
    shared_ptr<VFSHost> curr_host = _listing->Host();
    while(curr_host.get() != nullptr) {
        depth++;
        curr_host = curr_host->Parent();
    }
    
    if(depth == 0)
        return VFSPathStack();
    
    VFSPathStack ret;
    ret.m_Path.resize(depth);
    curr_host = _listing->Host();
    ret.m_Path.back().path = _listing->RelativePath();
    do {
        ret.m_Path[depth-1].fs_tag = curr_host->FSTag();
        if(depth > 1)
            ret.m_Path[depth - 2].path = curr_host->JunctionPath();
        curr_host = curr_host->Parent();
        --depth;
    } while(curr_host.get() != nullptr);
    
    assert(depth == 0);
        
    return ret;
}
