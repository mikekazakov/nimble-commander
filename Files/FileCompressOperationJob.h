//
//  FileCompressOperationJob.h
//  Files
//
//  Created by Michael G. Kazakov on 21.10.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once

#import "chained_strings.h"
#import "VFS.h"
#import "OperationJob.h"

@class FileCompressOperation;

class FileCompressOperationJob : public OperationJob
{
public:
    FileCompressOperationJob();
    ~FileCompressOperationJob();
    
    void Init(vector<string>&& _src_files,
              const string&_src_root,
              VFSHostPtr _src_vfs,
              const string&_dst_root,
              VFSHostPtr _dst_vfs,
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
        no_flags    = 0 << 0,
        is_dir      = 1 << 0,
        symlink     = 1 << 1
    };
    
    
    __unsafe_unretained FileCompressOperation    *m_Operation;
    vector<string>                  m_InitialItems;
    chained_strings                 m_ScannedItems;
    string                          m_SrcRoot;
    VFSHostPtr                      m_SrcVFS;
    string                          m_DstRoot;
    VFSHostPtr                      m_DstVFS;
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

