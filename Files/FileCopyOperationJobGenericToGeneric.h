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
    void BuildDirectories(const path &_dir, const VFSHostPtr& _host);
    void Analyze();
    void ScanItems();
    void ScanItem(const string &_full_path, const string &_short_path, const chained_strings::node *_prefix);
    void ProcessItems();
    void ProcessItem(const chained_strings::node *_node, int _number);

    bool CopyFileTo(const path &_src_full_path, const path &_dest_full_path);
    bool CopyDirectoryTo(const path &_src_full_path, const path &_dest_full_path);
    void RenameEntry(const path &_src_full_path, const path &_dest_full_path);
    
    void ProcessFilesRemoval();
    void ProcessFoldersRemoval();
    
    enum class ItemFlags
    {
        no_flags    = 0b0000,
        is_dir      = 0b0001,
    };

    enum class WorkMode
    {
        /**
         Files are copied into some "/dir/other/dir" structure and their filenames like
         
         "[base src path]abra/cadabra.txt"
         
         would be appended after this 'prefix':
         
         "/dir/other/dir/abra/cadabra.txt"
         
         @brief CopyToPathPreffix is a most used work mode - CopyTo.
         */
        CopyToPathPreffix,
        
        /**
         Files are copied into some "Entity". For SingleEntryCopy(single root element in list - MyFiles) that will cause a files like:
        
         [base src path]../MyFiles/1.txt
         
         [base src path]../MyFiles/2.txt
         
         will be copied into:
         
         [base src path]../Entity/1.txt
         
         [base src path]../Entity/2.txt
         
         @brief CopyToPathPreffix is usually a CopyAs.
         */
        CopyToPathName,
        
        /**
         Doing a massive files renaming from [base src path] to some other dir.
         @brief RenameToPathPreffix is basically a Rename To.
         */
        RenameToPathPreffix,
        
        /**
         Doing just like CopyToPathName, but renaming insted of copying.
         @brief RenameToPathName is basically a Rename As.
         */
        RenameToPathName,
        
        /**
         Just like RenameToPathPreffix but actually does copying and deleting source after.
         @brief MoveToPathPreffix is basically a Move To
         */
        MoveToPathPreffix
    };
    
    
    
    enum {
        m_BufferSize = (512*1024) // 512kb
    };
    
    __unsafe_unretained FileCopyOperation  *m_Operation;
    FileCopyOperationOptions                m_Options;
    chained_strings                         m_InitialItems;
    chained_strings                         m_ScannedItems;
    const chained_strings::node             *m_CurrentlyProcessingItem;

    vector<const chained_strings::node *>   m_FilesToDelete; // used for move* work mode
    vector<const chained_strings::node *>   m_DirsToDelete;  // used for move* work mode

    shared_ptr<VFSHost>                     m_OrigSrcHost;
    shared_ptr<VFSHost>                     m_OrigDstHost;
    shared_ptr<VFSHost>                     m_SrcHost;
    shared_ptr<VFSHost>                     m_DstHost;
    path                                    m_SrcDir;
    path                                    m_OriginalDestination;
    path                                    m_Destination;
    unique_ptr<uint8_t[]>                   m_Buffer = make_unique<uint8_t[]>(m_BufferSize);
    
    vector<uint8_t>                         m_ItemFlags;
    WorkMode                                m_WorkMode = WorkMode::CopyToPathPreffix;
    unsigned                                m_SourceNumberOfFiles = 0;
    unsigned                                m_SourceNumberOfDirectories = 0;
    uint64_t                                m_SourceTotalBytes = 0;
    uint64_t                                m_TotalCopied = 0;
    bool                                    m_IsSingleEntryCopy = false;
    bool                                    m_SkipAll = false;
    bool                                    m_OverwriteAll = false;
    bool                                    m_AppendAll = false;
};
