//
//  FileDeletionOperationJob.h
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../../OperationJob.h"
#include "FileDeletionOperation.h"
#include "../../chained_strings.h"

class FileDeletionOperationJob : public OperationJob
{
public:
    void Init(vector<string>&& _files, FileDeletionOperationType _type, const string &_dir, FileDeletionOperation *_op);
    
protected:
    virtual void Do();
    void DoScan();
    void DoScanDir(const char *_full_path, const chained_strings::node *_prefix);
    void DoFile(const char *_full_path, bool _is_dir);
    bool DoDelete(const char *_full_path, bool _is_dir);
    bool DoMoveToTrash(const char *_full_path, bool _is_dir);
    bool DoSecureDelete(const char *_full_path, bool _is_dir);
    
    vector<string>  m_RequestedFiles;
    chained_strings m_Directories; // this container will store directories structure in direct order
    chained_strings m_ItemsToDelete; // this container will store files and directories to direct, they will use m_Directories to link path
    FileDeletionOperationType   m_Type = FileDeletionOperationType::Invalid;
    string                      m_RootPath;
    unsigned                    m_CurrentItemNumber = 0;
    bool                        m_SkipAll = false;
    bool                        m_RootHasExternalEAs = false;
    
    __unsafe_unretained FileDeletionOperation *m_Operation = nil;
};
