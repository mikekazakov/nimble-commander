//
//  FileSysAttrChangeOperationJob.h
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../../OperationJob.h"
#include "../../chained_strings.h"
#include "filesysattr.h"

@class FileSysAttrChangeOperation;

class FileSysAttrChangeOperationJob : public OperationJob
{
public:
    FileSysAttrChangeOperationJob();
    ~FileSysAttrChangeOperationJob();
    void Init(shared_ptr<FileSysAttrAlterCommand> _command, FileSysAttrChangeOperation *_operation);

protected:
    virtual void Do();
    void ScanDirs();
    void ScanDir(const char *_full_path, const chained_strings::node *_prefix);
    
private:
    void DoFile(const char *_full_path);
    
    shared_ptr<FileSysAttrAlterCommand> m_Command;
    chained_strings m_Files;
    __unsafe_unretained FileSysAttrChangeOperation *m_Operation;
    bool m_SkipAllErrors;
};

