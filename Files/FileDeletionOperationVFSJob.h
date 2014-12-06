//
//  FileDeletionOperationVFSJob.h
//  Files
//
//  Created by Michael G. Kazakov on 08.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "OperationJob.h"
#import "FileDeletionOperation.h"


class FileDeletionOperationVFSJob : public OperationJob
{
public:

    void Init(vector<string>&& _files, const string &_root, const VFSHostPtr& _host, FileDeletionOperation *_op);
    
    
private:
    virtual void Do();    
    void DoScan();
    void DoScanDir(const path &_full_path, const chained_strings::node *_prefix);
    
    
    vector<string>      m_RequestedFiles;
    path                m_RootPath;
    VFSHostPtr          m_Host;

    
    chained_strings     m_Directories; // this container will store directories structure in direct order, used for path building
    chained_strings     m_ItemsToDelete; // this container will store files and directories to delete, they will use m_Directories to link path
    
    bool                m_SkipAll = false;
    __unsafe_unretained FileDeletionOperation *m_Operation = nil;
};
