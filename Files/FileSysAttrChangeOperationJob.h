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
#include "FlexChainedStringsChunk.h"

@class FileSysAttrChangeOperation;

class FileSysAttrChangeOperationJob : public OperationJob
{
public:
    FileSysAttrChangeOperationJob();
    ~FileSysAttrChangeOperationJob();
    void Init(FileSysAttrAlterCommand *_command, FileSysAttrChangeOperation *_operation);

protected:
    virtual void Do();
    void ScanDirs();
    void ScanDir(const char *_full_path, const FlexChainedStringsChunk::node *_prefix);
    
private:
    void DoFile(const char *_full_path);
    
    FileSysAttrAlterCommand *m_Command;
    FlexChainedStringsChunk *m_Files, *m_FilesLast;
    __weak FileSysAttrChangeOperation *m_Operation;
    bool m_SkipAllErrors;
};

