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
                             FileCopyOperationOptions* _opts,
                             FileCopyOperation *_op
              
                             );

    bool IsSingleFileCopy() const;
private:
    enum WorkMode
    {
        Unknown = 0,
        CopyToFolder,
        
        CopyToFile,
        
        RenameToFile,
        // our destination is a regular filename.
        // renaming multiple files to one filename will result in overwriting destination file - need to ask user about this action
        // [!] in this case we may need to remove destination first. but it's better to do nothing and to display an error
        
        RenameToFolder,
        // our destination is a folder name
        // we need to compose file name as destination folder name plus original relative file name
        
        MoveToFile,
        MoveToFolder
    };

    virtual void Do();
    void ScanDestination();
    void ScanItems();
    void ScanItem(const char *_full_path, const char *_short_path, const FlexChainedStringsChunk::node *_prefix);
    void ProcessItems();
    void ProcessItem(const FlexChainedStringsChunk::node *_node);
    void ProcessDirectoryCopying(const char *_path);
    void ProcessFileCopying(const char *_path);
    void ProcessRenameToFile(const char *_path); // _path is relative filename of source item
    void ProcessRenameToFolder(const char *_path); // _path is relative filename of source item
    
    void BuildDestinationDirectory(const char* _path);
    
    // does copying. _src and _dest should be a full paths
    // return true if copying was successful
    bool CopyFileTo(const char *_src, const char *_dest);
    
    __weak FileCopyOperation *m_Operation;
    FlexChainedStringsChunk *m_InitialItems;
    FlexChainedStringsChunk *m_ScannedItems, *m_ScannedItemsLast;
    const FlexChainedStringsChunk::node *m_CurrentlyProcessingItem;    
    char m_SourceDirectory[MAXPATHLEN];
    char m_Destination[MAXPATHLEN];
    unsigned m_SourceNumberOfFiles;
    unsigned m_SourceNumberOfDirectories;
    unsigned long m_SourceTotalBytes;
    unsigned long m_TotalCopied;
    WorkMode m_WorkMode;
    void *m_Buffer1;
    void *m_Buffer2;
    dispatch_queue_t m_ReadQueue;
    dispatch_queue_t m_WriteQueue;
    dispatch_group_t m_IOGroup;
    bool m_SkipAll;
    bool m_OverwriteAll;
    bool m_AppendAll;
    bool m_IsSingleFileCopy;
    
    bool m_IsCopying; // true means that user wants to perform copy operation, false mean rename/move
    bool m_SameVolume; // true means that source and destination are located at the same file system
};


