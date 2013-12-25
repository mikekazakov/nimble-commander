//
//  FileCompressOperationJob.h
//  Files
//
//  Created by Michael G. Kazakov on 21.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import <vector>
#import "chained_strings.h"
#import "VFS.h"
#import "OperationJob.h"

@class FileCompressOperation;

class FileCompressOperationJob : public OperationJob
{
public:
    FileCompressOperationJob();
    ~FileCompressOperationJob();
    
    void Init(chained_strings _src_files,
              const char*_src_root,
              shared_ptr<VFSHost> _src_vfs,
              const char* _dst_root,
              shared_ptr<VFSHost> _dst_vfs,
              FileCompressOperation *_operation);
    
    
    const char *TargetFileName() const;
    unsigned FilesAmount() const;
    bool IsDoneScanning() const;
private:
    virtual void Do();
    void ScanItems();
    void ScanItem(const char *_full_path, const char *_short_path, const chained_strings::node *_prefix);
    void ProcessItems();
    void ProcessItem(const chained_strings::node *_node, int _number);
    bool FindSuitableFilename(char* _full_filename);
    static ssize_t	la_archive_write_callback(struct archive *, void *_client_data, const void *_buffer, size_t _length);
    
    enum class ItemFlags
    {
        no_flags    = 0,
        is_dir      = 1 << 0,
    };
    
    
    __weak FileCompressOperation    *m_Operation;
    chained_strings                 m_InitialItems;
    chained_strings                 m_ScannedItems;
    char                            m_SrcRoot[MAXPATHLEN];
    shared_ptr<VFSHost>        m_SrcVFS;
    char                            m_DstRoot[MAXPATHLEN];
    shared_ptr<VFSHost>        m_DstVFS;
    char                            m_TargetFileName[MAXPATHLEN];
    bool                            m_DoneScanning;
    bool m_SkipAll;
    const chained_strings::node     *m_CurrentlyProcessingItem;
    uint64_t                        m_SourceTotalBytes;
    uint64_t                        m_TotalBytesProcessed;
    vector<uint8_t>            m_ItemFlags;
    struct archive                  *m_Archive;
    shared_ptr<VFSFile>        m_TargetFile;
};

