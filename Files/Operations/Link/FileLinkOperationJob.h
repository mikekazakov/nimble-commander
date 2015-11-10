//
//  FileLinkOperationJob.h
//  Files
//
//  Created by Michael G. Kazakov on 30.06.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "../../OperationJob.h"
#include "FileLinkOperation.h"

class FileLinkOperationJob : public OperationJob
{
public:
    enum class Mode
    {
        CreateSymLink,
        AlterSymlink,
        CreateHardLink
    };
    
    FileLinkOperationJob();
    ~FileLinkOperationJob();
    
    void Init(const char* _orig_file, const char *_link_file, Mode _mode, FileLinkOperation *_op);

protected:
    virtual void Do();
    
private:
    void DoNewHardLink();
    void DoNewSymLink();
    void DoAlterSymLink();
    
    FileLinkOperationJob(const FileLinkOperationJob&);
    void operator=(const FileLinkOperationJob&);
    
    char m_File[MAXPATHLEN];
    char m_Link[MAXPATHLEN];
    Mode m_Mode;
    __unsafe_unretained FileLinkOperation *m_Op;
};

    
    
