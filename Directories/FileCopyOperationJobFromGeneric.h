//
//  FileCopyOperationJobFromGeneric.h
//  Files
//
//  Created by Michael G. Kazakov on 10.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import <vector>

#import "OperationJob.h"
#import "FileCopyOperation.h"
#import "VFS.h"

// copy from generic vfs host to native file system
class FileCopyOperationJobFromGeneric : public OperationJob
{
public:
    FileCopyOperationJobFromGeneric();
    ~FileCopyOperationJobFromGeneric();

    void Init(FlexChainedStringsChunk *_src_files, // passing ownage to Job
              const char *_src_root,               // dir in where files are located
              std::shared_ptr<VFSHost> _src_host,  // src host to deal with
              const char *_dest,                   // where to copy
              FileCopyOperationOptions* _opts,
              FileCopyOperation *_op
              );
    
private:
    virtual void Do();
    bool CheckDestinationIsValidDir();
    void ScanItems();
    void ScanItem(const char *_full_path, const char *_short_path, const FlexChainedStringsChunk::node *_prefix);    
    void ProcessItems();
    void ProcessItem(const FlexChainedStringsChunk::node *_node, int _number);
    bool CopyFileTo(const char *_src, const char *_dest);
    bool CopyDirectoryTo(const char *_src, const char *_dest);
    
    
    enum class ItemFlags
    {
        no_flags    = 0,
        is_dir      = 1 << 0,
//        is_symlink  = 1 << 1
    };
    
    __weak FileCopyOperation *m_Operation;
    FileCopyOperationOptions m_Options;    
    FlexChainedStringsChunk *m_InitialItems;
    FlexChainedStringsChunk *m_ScannedItems, *m_ScannedItemsLast;
    const FlexChainedStringsChunk::node *m_CurrentlyProcessingItem;    

    std::shared_ptr<VFSHost> m_SrcHost;
    char                     m_SrcDir[MAXPATHLEN];
    char                     m_Destination[MAXPATHLEN];
    
    void *m_Buffer1;
    void *m_Buffer2;    
    dispatch_queue_t m_ReadQueue;
    dispatch_queue_t m_WriteQueue;
    dispatch_group_t m_IOGroup;
    
    std::vector<uint8_t> m_ItemFlags;    
    unsigned m_SourceNumberOfFiles;
    unsigned m_SourceNumberOfDirectories;
    unsigned long m_SourceTotalBytes;
    unsigned long m_TotalCopied;
    bool m_SkipAll;
    bool m_OverwriteAll;
    bool m_AppendAll;
    
};
