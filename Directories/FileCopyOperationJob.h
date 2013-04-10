//
//  FileCopyOperationJob.h
//  Directories
//
//  Created by Michael G. Kazakov on 09.04.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "OperationJob.h"
#import "FileCopyOperation.h"
#import "FlexChainedStringsChunk.h"


class FileCopyOperationJob : public OperationJob
{
public:
    FileCopyOperationJob();
    ~FileCopyOperationJob();

    void Init(FlexChainedStringsChunk *_files, // passing ownage to Job
                             const char *_root,               // dir in where files are located
                             const char *_dest,                // where to copy
                             FileCopyOperation *_op
                             );

private:
    enum CopyMode
    {
        CopyUnknown = 0,
        CopyToFolder,
        CopyToFile
    };

    virtual void Do();
    void ScanDestination();
    void ScanItems();
    void ScanItem(const char *_full_path, const char *_short_path, const FlexChainedStringsChunk::node *_prefix);
    void ProcessItems();
    void ProcessItem(const FlexChainedStringsChunk::node *_node);
    void ProcessDirectory(const char *_path);
    void ProcessFile(const char *_path);    
    
    FileCopyOperation *m_Operation;
    FlexChainedStringsChunk *m_InitialItems;
    FlexChainedStringsChunk *m_ScannedItems, *m_ScannedItemsLast;
    const FlexChainedStringsChunk::node *m_CurrentlyProcessingItem;    
    char m_SourceDirectory[MAXPATHLEN];
    char m_Destination[MAXPATHLEN];
    unsigned m_SourceNumberOfFiles;
    unsigned m_SourceNumberOfDirectories;
    unsigned long m_SourceTotalBytes;
    unsigned long m_TotalCopied;
    CopyMode m_CopyMode;
    void *m_Buffer1;
    void *m_Buffer2;
    dispatch_queue_t m_ReadQueue;
    dispatch_queue_t m_WriteQueue;
    dispatch_group_t m_IOGroup;
    bool m_SkipAll;
    bool m_OverwriteAll;
    bool m_AppendAll;
};


