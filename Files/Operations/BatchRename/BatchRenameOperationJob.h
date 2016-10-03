//
//  BatchRenameOperationJob.h
//  Files
//
//  Created by Michael G. Kazakov on 13/06/15.
//  Copyright (c) 2015 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <VFS/VFS.h>
#include "../OperationJob.h"

@class BatchRenameOperation;

class BatchRenameOperationJob : public OperationJob
{
public:
    BatchRenameOperationJob();

    void Init(vector<string>&& _src_paths,
              vector<string>&& _dst_paths,
              VFSHostPtr _vfs,
              BatchRenameOperation *_operation);
    
private:
    virtual void Do() override;
    
    
    vector<string>  m_SrcPaths;
    vector<string>  m_DstPaths;
    void ProcessItem(const string &_orig, const string &_renamed);
    
    VFSHostPtr      m_VFS;
    __unsafe_unretained BatchRenameOperation *m_Operation;
    bool            m_SkipAll = false;
};
