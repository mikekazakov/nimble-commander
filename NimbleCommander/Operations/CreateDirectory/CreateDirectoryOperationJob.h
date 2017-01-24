//
//  CreateDirectoryOperationJob.h
//  Directories
//
//  Created by Michael G. Kazakov on 08.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <NimbleCommander/Operations/OperationJob.h>
#include "CreateDirectoryOperation.h"

class CreateDirectoryOperationJob : public OperationJob
{
public:
    void Init(const char *_path, const char *_root_path, CreateDirectoryOperation *_operation);
    
protected:
    virtual void Do();
    
private:
    __unsafe_unretained CreateDirectoryOperation *m_Operation = nil;
    char m_Name[MAXPATHLEN];
    char m_Path[MAXPATHLEN];
    char m_RootPath[MAXPATHLEN];
};

