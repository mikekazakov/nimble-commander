//
//  FileCopyOperationJobGenericToGeneric.h
//  Files
//
//  Created by Michael G. Kazakov on 24.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <vector>
#import "OperationJob.h"
#import "FileCopyOperation.h"
#import "DispatchQueue.h"
#import "VFS.h"

// copy from generic vfs host to native file system
class FileCopyOperationJobGenericToGeneric : public OperationJob
{
public:
    FileCopyOperationJobGenericToGeneric();
    ~FileCopyOperationJobGenericToGeneric();
    
    void Init(chained_strings _src_files,
              const path &_src_root,               // dir in where files are located
              shared_ptr<VFSHost> _src_host,       // src host to deal with
              const path &_dest,                   // where to copy
              shared_ptr<VFSHost> _dst_host,       // dst host to deal with
              FileCopyOperationOptions _opts,
              FileCopyOperation *_op
              );
    
    
    
private:
    virtual void Do();
    void ScanItems();
    void ScanItem(const char *_full_path, const char *_short_path, const chained_strings::node *_prefix);
    void ProcessItems();
    void ProcessItem(const chained_strings::node *_node, int _number);

    void CopyFileTo(const path &_src, const path &_dest);
    
    enum class ItemFlags
    {
        no_flags    = 0b0000,
        is_dir      = 0b0001,
    };

    enum {
        BUFFER_SIZE = (512*1024) // 512kb
    };
    
    __unsafe_unretained FileCopyOperation  *m_Operation;
    FileCopyOperationOptions                m_Options;
    chained_strings                         m_InitialItems;
    chained_strings                         m_ScannedItems;
    const chained_strings::node             *m_CurrentlyProcessingItem;
    
    shared_ptr<VFSHost>                     m_SrcHost;
    shared_ptr<VFSHost>                     m_DstHost;
    path                                    m_SrcDir;
    path                                    m_OriginalDestination;
    path                                    m_Destination;
    unique_ptr<uint8_t[]>                   m_Buffer = make_unique<uint8_t[]>(BUFFER_SIZE);
    
    vector<uint8_t>                         m_ItemFlags;
    bool m_SkipAll = false;
    bool m_OverwriteAll = false;
    bool m_AppendAll = false;
    
};
