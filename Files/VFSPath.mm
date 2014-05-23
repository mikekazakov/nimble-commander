//
//  VFSPath.mm
//  Files
//
//  Created by Michael G. Kazakov on 20.12.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#import "VFS.h"

VFSPathStack::VFSPathStack(shared_ptr<VFSListing> _listing)
{
    // 1st - calculate host's depth
    int depth = 0;
    VFSHost* curr_host = _listing->Host().get();
    while(curr_host != nullptr) {
        depth++;
        curr_host = curr_host->Parent().get();
    }
    
    if(depth == 0)
        return; // we're empty - invalid case
    
    // build vfs stack
    m_Stack.resize(depth);
    curr_host = _listing->Host().get();
    do {
        m_Stack[depth-1].fs_tag = curr_host->FSTag();
        m_Stack[depth-1].junction = curr_host->JunctionPath();
        m_Stack[depth-1].host = curr_host->shared_from_this();
        curr_host = curr_host->Parent().get();
        --depth;
    } while(curr_host != nullptr);
    
    // remember relative path we're at
    m_Path = _listing->RelativePath();
}

VFSPathStack::VFSPathStack(const VFSPathStack&_r):
    m_Stack(_r.m_Stack),
    m_Path(_r.m_Path)
{
}

VFSPathStack::VFSPathStack(VFSPathStack&&_r):
    m_Stack(move(_r.m_Stack)),
    m_Path(move(_r.m_Path))
{
}


