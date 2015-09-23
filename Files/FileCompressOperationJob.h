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
    
    void Init(vector<VFSFlexibleListingItem> _src_files,
              const string&_dst_root,
              VFSHostPtr _dst_vfs,
              FileCompressOperation *_operation);
    
    
    string TargetFileName() const;
    unsigned FilesAmount() const;
    bool IsDoneScanning() const;
private:
    virtual void Do();
    void ScanItems();
    void ScanItem(const char *_full_path, const char *_short_path, unsigned _vfs_no, unsigned _basepath_no, const chained_strings::node *_prefix);
    void ProcessItems();
    void ProcessItem(const chained_strings::node *_node, int _index);
    string FindSuitableFilename(const string& _proposed_arcname) const;
    uint8_t FindOrInsertHost(const VFSHostPtr &_h);
    unsigned FindOrInsertBasePath(const string &_path);
    static ssize_t	la_archive_write_callback(struct archive *, void *_client_data, const void *_buffer, size_t _length);
    
    enum class ItemFlags
    {
        no_flags    = 0 << 0,
        is_dir      = 1 << 0,
        symlink     = 1 << 1
    };
    
    struct SourceItemMeta
    {
        unsigned    base_path;      // m_BasePaths index
        uint16_t    vfs;            // m_SourceHosts index
        uint8_t     flags;
    };
    
    __unsafe_unretained FileCompressOperation    *m_Operation;
    optional<vector<VFSFlexibleListingItem>> m_InitialListingItems;
    chained_strings                 m_ScannedItems;
    vector<SourceItemMeta>          m_ScannedItemsMeta;
    
    vector<VFSHostPtr>              m_SourceHosts;
    vector<string>                  m_BasePaths;

    string                          m_DstRoot;
    VFSHostPtr                      m_DstVFS;
    string                          m_TargetFileName;
    bool                            m_DoneScanning;
    bool m_SkipAll;
    const chained_strings::node     *m_CurrentlyProcessingItem;
    uint64_t                        m_SourceTotalBytes;
    uint64_t                        m_TotalBytesProcessed;

    struct archive                  *m_Archive;
    shared_ptr<VFSFile>        m_TargetFile;
};

