//
//  FileSysAttrChangeOperationJob.h
//  Directories
//
//  Created by Michael G. Kazakov on 02.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include <NimbleCommander/Operations/OperationJob.h>
#include "FileSysAttrChangeOperationCommand.h"

@class FileSysAttrChangeOperation;

class FileSysAttrChangeOperationJob : public OperationJob
{
public:
    FileSysAttrChangeOperationJob();
    void Init(FileSysAttrAlterCommand _command, FileSysAttrChangeOperation *_operation);

private:
    struct SourceItem
    {
        // full path = m_SourceItemsBaseDirectories[base_dir_index] + ... + m_Items[m_Items[parent_index].parent_index].item_name +  m_Items[parent_index].item_name + item_name;
        string      item_name;
        int         parent_index = -1;
        unsigned    base_dir_index;
    };
    
    virtual void Do();
    void DoScan();

    void DoFile(const char *_full_path);
    string ComposeFullPath( const SourceItem &_item ) const;
    
    

    
    FileSysAttrAlterCommand             m_Command;
    vector<string>                      m_SourceItemsBaseDirectories;
    vector<SourceItem>                  m_SourceItems;
    __unsafe_unretained FileSysAttrChangeOperation *m_Operation;
    bool m_SkipAllErrors = false;
};

