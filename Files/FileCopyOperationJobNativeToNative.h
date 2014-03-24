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
#import "chained_strings.h"
#import "DispatchQueue.h"
#import <vector>

class FileCopyOperationJobNativeToNative : public OperationJob
{
public:
    FileCopyOperationJobNativeToNative();
    ~FileCopyOperationJobNativeToNative();

    void Init(chained_strings _files,
                             const char *_root,               // dir in where files are located
                             const char *_dest,                // where to copy
                             FileCopyOperationOptions* _opts,
                             FileCopyOperation *_op
              
                             );

    bool IsSingleFileCopy() const;
    
    enum StatValueType
    {
        StatValueUnknown,
        StatValueBytes,
        StatValueFiles
    };
    
    StatValueType GetStatValueType() const;
    
private:
    enum class ItemFlags
    {
        no_flags    = 0b0000,
        is_dir      = 0b0001,
        is_symlink  = 0b0010,
    };
    
    enum WorkMode
    {
        Unknown = 0,
        CopyToPathPreffix,
        
        CopyToFixedPath,
        
        RenameToFixedPath,
        // our destination is a regular filename.
        // renaming multiple files to one filename will result in overwriting destination file - need to ask user about this action
        // [!] in this case we may need to remove destination first. but it's better to do nothing and to display an error
        
        RenameToPathPreffix,
        // our destination is a folder name
        // we need to compose file name as destination folder name plus original relative file name
        
        MoveToFixedPath,
        MoveToPathPreffix
        
        // when moving files we actualy do two things:
        // 1) copying source to destination - copy every item into receiver
        //      while copying - compose a list of entries that later has to be deleted
        // 2) remove every item from that list, do it only if item was copied without errors (in list of such files)
        //     removing is done in two steps - first we delete every file and then delete every directory
    };

    virtual void Do();
    void ScanDestination();
    void ScanItems();
    void ScanItem(const char *_full_path, const char *_short_path, const chained_strings::node *_prefix);
    void ProcessItems();
    void ProcessItem(const chained_strings::node *_node, int _number);
    
    // _path is relative filename of source item
    void ProcessCopyToPathPreffix(const char *_path, int _number);
    void ProcessCopyToFixedPath(const char *_path, int _number);
    void ProcessRenameToFixedPath(const char *_path, int _number);
    void ProcessRenameToPathPreffix(const char *_path, int _number);
    void ProcessMoveToPathPreffix(const char *_path, int _number);
    void ProcessMoveToFixedPath(const char *_path, int _number);
    
    void ProcessFilesRemoval();
    void ProcessFoldersRemoval();
    void BuildDestinationDirectory(const char* _path);
    
    // does copying. _src and _dest should be a full paths
    // return true if copying was successful
    bool CopyFileTo(const char *_src, const char *_dest);
    bool CopyDirectoryTo(const char *_src, const char *_dest);
    bool CreateSymlinkTo(const char *_source_symlink, const char* _tagret_symlink);
    
    void EraseXattrs(int _fd_in);
    void CopyXattrs(int _fd_from, int _fd_to);
    
    __unsafe_unretained FileCopyOperation *m_Operation;
    chained_strings m_InitialItems;
    chained_strings m_ScannedItems;
    
    vector<uint8_t> m_ItemFlags;
    vector<const chained_strings::node *> m_FilesToDelete; // used for move work mode
    vector<const chained_strings::node *> m_DirsToDelete; // used for move work mode
    const chained_strings::node *m_CurrentlyProcessingItem;
    char m_SourceDirectory[MAXPATHLEN];
    char m_Destination[MAXPATHLEN];
    unsigned m_SourceNumberOfFiles;
    unsigned m_SourceNumberOfDirectories;
    unsigned long m_SourceTotalBytes;
    unsigned long m_TotalCopied;
    WorkMode m_WorkMode;
    void *m_Buffer1;
    void *m_Buffer2;
    DispatchGroup m_IOGroup;
    bool m_SkipAll;
    bool m_OverwriteAll;
    bool m_AppendAll;
    bool m_IsSingleFileCopy;
    bool m_SourceHasExternalEAs;
    bool m_DestinationHasExternalEAs;
    
    FileCopyOperationOptions m_Options;
    bool m_IsSingleEntryCopy;
    bool m_SameVolume; // true means that source and destination are located at the same file system
};


