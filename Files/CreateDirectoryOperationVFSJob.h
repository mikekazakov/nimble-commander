//
//  CreateDirectoryOperationVFSJob.h
//  Files
//
//  Created by Michael G. Kazakov on 08.05.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "OperationJob.h"
#import "CreateDirectoryOperation.h"
#import "VFS.h"

class CreateDirectoryOperationVFSJob : public OperationJob
{
public:
    void Init(const string &_path, const path &_root_path, const VFSHostPtr& _host, CreateDirectoryOperation *_operation);
    
protected:
    virtual void Do();
    
private:
    __unsafe_unretained CreateDirectoryOperation *m_Operation = nil;
    string m_RequestedPath;
    path m_ResultPath;
    path m_RootPath;
    VFSHostPtr m_Host;
};

