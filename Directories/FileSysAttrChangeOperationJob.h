//
//  FileSysAttrChangeOperationJob.h
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "OperationJob.h"
#include "filesysattr.h"

@class FileSysAttrChangeOperation;

class FileSysAttrChangeOperationJob : public OperationJob
{
public:

    void Init(FileSysAttrAlterCommand *_command);
    
protected:
    virtual void Do();

private:
    void DoFile(const char *_full_path);
    
    FileSysAttrAlterCommand *m_Command;
};

