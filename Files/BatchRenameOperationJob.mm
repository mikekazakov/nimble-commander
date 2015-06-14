//
//  BatchRenameOperationJob.cpp
//  Files
//
//  Created by Michael G. Kazakov on 13/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#import "BatchRenameOperationJob.h"
#import "BatchRenameOperation.h"

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
    
    m_Stats.StartTimeTracking();
    m_Stats.SetMaxValue(m_SrcPaths.size());
    
    
    for(size_t i = 0, e = m_SrcPaths.size(); i!=e; ++i) {
        if(CheckPauseOrStop()) { SetStopped(); return; }

        m_Stats.SetCurrentItem(m_SrcPaths[i].c_str());
        
        ProcessItem(m_SrcPaths[i], m_DstPaths[i]);
        
        m_Stats.AddValue(1);
    }
    
    m_Stats.SetCurrentItem(nullptr);
    if(CheckPauseOrStop()) { SetStopped(); return; }
    SetCompleted();
}

void BatchRenameOperationJob::ProcessItem(const string &_orig, const string &_renamed)
{
    if(_orig == _renamed)
        return;
    
    int ret = 0;
retry_rename:
    ret = m_VFS->Rename(_orig.c_str(), _renamed.c_str(), nullptr);
    if(ret != 0) { // failed to rename
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation DialogOnRenameError:VFSError::ToNSError(ret) source:_orig destination:_renamed] WaitForResult];
        if(result == OperationDialogResult::Retry) goto retry_rename;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
cleanup:;
}
