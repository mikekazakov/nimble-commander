//
//  FileCopyOperationJobFromGeneric.h
//  Files
//
//  Created by Michael G. Kazakov on 10.09.13.
//  Copyright (c) 2013 Michael G. Kazakov. All rights reserved.
//

#pragma once
#import "OperationJob.h"
#import "FileCopyOperation.h"
#import "DispatchQueue.h"
#import "VFS.h"

// copy from generic vfs host to native file system
class FileCopyOperationJobFromGeneric : public OperationJob
{
public:
    FileCopyOperationJobFromGeneric();
    ~FileCopyOperationJobFromGeneric();

    void Init(chained_strings _src_files,
              const char *_src_root,               // dir in where files are located
              shared_ptr<VFSHost> _src_host,  // src host to deal with
              const char *_dest,                   // where to copy
              FileCopyOperationOptions _opts,
              FileCopyOperation *_op
              );
    
private:
    virtual void Do();
    bool CheckDestinationIsValidDir();
    void ScanItems();
    void ScanItem(const char *_full_path, const char *_short_path, const chained_strings::node *_prefix);
    void ProcessItems();
    void ProcessItem(const chained_strings::node *_node, int _number);
    bool CopyFileTo(const char *_src, const char *_dest);
    bool CopyDirectoryTo(const char *_src, const char *_dest);
    void EraseXattrs(int _fd_in);
    void CopyXattrs(shared_ptr<VFSFile> _file, int _fd_to);
    void CopyXattrsFn(shared_ptr<VFSFile> _file, const char *_fn_to);
    
    enum class ItemFlags
    {
        no_flags    = 0b0000,
        is_dir      = 0b0001,
    };
    
    enum {
        m_BufferSize = (512*1024) // 512kb
    };
    
    __unsafe_unretained FileCopyOperation *m_Operation;
    FileCopyOperationOptions m_Options;    
    chained_strings m_InitialItems;
    chained_strings m_ScannedItems;
    const chained_strings::node *m_CurrentlyProcessingItem;    

    shared_ptr<VFSHost> m_SrcHost;
    char                     m_SrcDir[MAXPATHLEN];
    char                     m_Destination[MAXPATHLEN];
    
    unique_ptr<uint8_t[]>    m_Buffer1 = make_unique<uint8_t[]>(m_BufferSize);
    unique_ptr<uint8_t[]>    m_Buffer2 = make_unique<uint8_t[]>(m_BufferSize);
    
    DispatchGroup m_IOGroup;
    
    vector<uint8_t> m_ItemFlags;    
    unsigned m_SourceNumberOfFiles;
    unsigned m_SourceNumberOfDirectories;
    unsigned long m_SourceTotalBytes;
    unsigned long m_TotalCopied;
    bool m_SkipAll;
    bool m_OverwriteAll;
    bool m_AppendAll;
    
};
