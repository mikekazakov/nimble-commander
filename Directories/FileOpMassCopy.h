//
//  FileOpMassCopy.h
//  Directories
//
//  Created by Michael G. Kazakov on 12.03.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#include "FileOp.h"

#include "FlexChainedStringsChunk.h"

class PanelData;
@class MainWindowController;

class FileOpMassCopy : public AbstractFileJob
{
public:
    enum OpState
    {
        StateScanning,
        StateCopying,
        stateCanceled // ?
    };
        
    FileOpMassCopy();
    ~FileOpMassCopy();
    
    // grab selected items from _source.
    // perform deep scanning in other thread, tries to finish this method as soon as possible
    void InitOpDataWithPanel(const PanelData&_source, const char *_dest, MainWindowController *_wnd);
    void Run();
    
    OpState State() const;
    const FlexChainedStringsChunk::node *CurrentlyProcessingItem() const;

private:
    enum CopyMode
    {
        CopyUnknown = 0,
        CopyToFolder,
        CopyToFile
    };

    void DoRun();
    void DoCleanup();
    bool ScanDestination();
    bool ScanItems();
    bool ScanItem(const char *_full_path, const char *_short_path, const FlexChainedStringsChunk::node *_prefix);
    void ProcessItems();
    void ProcessItem(const FlexChainedStringsChunk::node *_node);
    void ProcessDirectory(const char *_path);
    void ProcessFile(const char *_path);
    MainWindowController *m_Wnd;
    FlexChainedStringsChunk *m_InitialItems;
    FlexChainedStringsChunk *m_ScannedItems;
    FlexChainedStringsChunk *m_ScannedItemsLast;
    char m_SourceDirectory[__DARWIN_MAXPATHLEN];
    char m_Destination[__DARWIN_MAXPATHLEN];

    const FlexChainedStringsChunk::node *m_CurrentlyProcessingItem;
    CopyMode m_CopyMode;
    OpState  m_OpState;
    unsigned m_SourceNumberOfFiles;
    unsigned m_SourceNumberOfDirectories;
    unsigned long m_SourceTotalBytes;
    unsigned long m_TotalCopied;
    void *m_Buffer1;
    void *m_Buffer2;
    dispatch_queue_t m_ReadQueue;
    dispatch_queue_t m_WriteQueue;
    dispatch_group_t m_IOGroup;

    bool m_SkipAll;
    bool m_OverwriteAll;
    bool m_AppendAll;
    bool m_Cancel;
};
