//
//  CreateDirectoryOperationVFSJob.cpp
//  Files
//
//  Created by Michael G. Kazakov on 08.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "CreateDirectoryOperationVFSJob.h"

void CreateDirectoryOperationVFSJob::Init(const string &_path,
                                          const path &_root_path,
                                          const VFSHostPtr& _host,
                                          CreateDirectoryOperation *_op)
{
    assert(!_path.empty());
    assert(_root_path.is_absolute());
    assert(_host);
    assert(!_host->IsNativeFS()); // for native FS please use direct FileDeletionOperationJob
    assert(_op);
    
    m_RequestedPath = _path;
    m_Host = _host;
    m_RootPath = _root_path;
    m_Operation = _op;
  
    if(m_RequestedPath[0] == '/')
        m_ResultPath = m_RequestedPath;
    else
        m_ResultPath = m_RootPath / m_RequestedPath;
}

void CreateDirectoryOperationVFSJob::Do()
{
    vector<path> to_create;

    path tmp = m_ResultPath;
    if(tmp.filename() == ".") tmp.remove_filename();
    
    while( tmp != "/" )
    {
        VFSStat st;
        if(m_Host->Stat(tmp.c_str(), st, 0, 0) == 0)
            break;
        to_create.emplace_back(tmp);
        tmp = tmp.parent_path();
    }
    
    m_Stats.StartTimeTracking();
    m_Stats.SetMaxValue(to_create.size());
    
    for(auto i = rbegin(to_create); i != rend(to_create); ++i)
    {
        mkdir:;
        int ret = m_Host->CreateDirectory(i->c_str(), 0640, 0);
        if(ret != 0)
        {
            int result = [[m_Operation DialogOnCrDirVFSError:ret ForDir:i->c_str()] WaitForResult];
            if (result == OperationDialogResult::Retry)
                goto mkdir;
            if (result == OperationDialogResult::Stop)
            {
                SetStopped();
                return;
            }
        }
        
        m_Stats.AddValue(1);
        if(CheckPauseOrStop()) { SetStopped(); return; }
    }
    
    if(CheckPauseOrStop()) { SetStopped(); return; }
    SetCompleted();
}
