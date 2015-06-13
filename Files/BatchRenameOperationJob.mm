//
//  BatchRenameOperationJob.cpp
//  Files
//
//  Created by Michael G. Kazakov on 13/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#include "BatchRenameOperationJob.h"


BatchRenameOperationJob::BatchRenameOperationJob()
{
}

void BatchRenameOperationJob::Init(vector<string>&& _src_paths,
                                   vector<string>&& _dst_paths,
                                   VFSHostPtr _vfs,
                                   BatchRenameOperation *_operation)
{
    m_Operation = _operation;
    m_SrcPaths = move(_src_paths);
    m_DstPaths = move(_dst_paths);
    m_VFS = _vfs;
}

void BatchRenameOperationJob::Do()
{
    if(m_SrcPaths.size() != m_DstPaths.size())
        throw logic_error("invalid parameters in BatchRenameOperationJob");
    
    
    for(size_t i = 0, e = m_SrcPaths.size(); i!=e; ++i) {
        if(CheckPauseOrStop()) { SetStopped(); return; }
        ProcessItem(m_SrcPaths[i], m_DstPaths[i]);
    }
    
    if(CheckPauseOrStop()) { SetStopped(); return; }
    SetCompleted();
}

void BatchRenameOperationJob::ProcessItem(const string &_orig, const string &_renamed)
{
    int ret = 0;
    
    ret = m_VFS->Rename(_orig.c_str(), _renamed.c_str(), nullptr);
    // error handling
    
}
