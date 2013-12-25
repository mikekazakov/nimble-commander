//
//  FileDeletionOperationJob.h
//  Directories
//
//  Created by Michael G. Kazakov on 05.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "OperationJob.h"
#import "FileDeletionOperation.h"


class FileDeletionOperationJob : public OperationJob
{
public:
    FileDeletionOperationJob();
    ~FileDeletionOperationJob();

    void Init(chained_strings _files, FileDeletionOperationType _type, const char* _root,
              FileDeletionOperation *_op);
    
protected:
    virtual void Do();
    void DoScan();
    void DoScanDir(const char *_full_path, const chained_strings::node *_prefix);
    void DoFile(const char *_full_path, bool _is_dir);
    bool DoDelete(const char *_full_path, bool _is_dir);
    bool DoMoveToTrash(const char *_full_path, bool _is_dir);
    bool DoSecureDelete(const char *_full_path, bool _is_dir);
    
    chained_strings m_RequestedFiles;
    chained_strings m_Directories; // this container will store directories structure in direct order
    chained_strings m_ItemsToDelete; // this container will store files and directories to direct, they will use m_Directories to link path
    FileDeletionOperationType m_Type;
    char m_RootPath[MAXPATHLEN];
    unsigned m_ItemsCount;
    unsigned m_CurrentItemNumber;
    State m_State;
    bool m_SkipAll;
    
    __weak FileDeletionOperation *m_Operation;
};
