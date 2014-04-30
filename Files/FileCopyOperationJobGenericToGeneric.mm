//
//  FileCopyOperationJobGenericToGeneric.cpp
//  Files
//
//  Created by Michael G. Kazakov on 24.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "FileCopyOperationJobGenericToGeneric.h"

FileCopyOperationJobGenericToGeneric::FileCopyOperationJobGenericToGeneric()
{
}

FileCopyOperationJobGenericToGeneric::~FileCopyOperationJobGenericToGeneric()
{
}

void FileCopyOperationJobGenericToGeneric::Init(chained_strings _src_files,
                                                const path &_src_root,               // dir in where files are located
                                                shared_ptr<VFSHost> _src_host,       // src host to deal with
                                                const path &_dest,                   // where to copy
                                                shared_ptr<VFSHost> _dst_host,       // dst host to deal with
                                                FileCopyOperationOptions _opts,
                                                FileCopyOperation *_op
                                                )
{
    assert(_src_host);
    assert(_dst_host);
    assert(_src_root.is_absolute());
    m_Operation = _op;
    m_InitialItems = move(_src_files);
    m_Options = _opts;
    m_SrcHost = _src_host;
    m_SrcDir = _src_root;
    
    m_Destination = m_OriginalDestination = _dest;
    m_DstHost = _dst_host;
}

void FileCopyOperationJobGenericToGeneric::Do()
{
    sleep(1); // what for????
   // int a = 10;
    
    ScanItems();

    ProcessItems();
    
    SetCompleted();
}

void FileCopyOperationJobGenericToGeneric::ScanItems()
{
    // iterate in original filenames
    for(const auto&i: m_InitialItems)
    {
        ScanItem(i.c_str(), i.c_str(), 0);
        
        if(CheckPauseOrStop()) return;
    }
}

void FileCopyOperationJobGenericToGeneric::ScanItem(const char *_full_path, const char *_short_path, const chained_strings::node *_prefix)
{
    path fullpath = m_SrcDir / _full_path;
    
    VFSStat stat_buffer;
    
retry_stat:
    int stat_ret = m_SrcHost->Stat(fullpath.c_str(), stat_buffer, 0, 0); // no symlinks support currently
    
    if(stat_ret == VFSError::Ok)
    {
        if(S_ISREG(stat_buffer.mode))
        {
            m_ItemFlags.push_back((uint8_t)ItemFlags::no_flags);
            m_ScannedItems.push_back(_short_path, _prefix);
//            m_SourceNumberOfFiles++;
//            m_SourceTotalBytes += stat_buffer.size;
        }
        else if(S_ISDIR(stat_buffer.mode))
        {
            char dirpath[MAXPATHLEN];
            sprintf(dirpath, "%s/", _short_path);
            m_ItemFlags.push_back((uint8_t)ItemFlags::is_dir);
            m_ScannedItems.push_back(dirpath, _prefix);
            auto dirnode = &m_ScannedItems.back();
            
        retry_opendir:
            int iter_ret = m_SrcHost->IterateDirectoryListing(fullpath.c_str(), ^bool(const VFSDirEnt &_dirent){
                char dirpathnested[MAXPATHLEN];
                sprintf(dirpathnested, "%s/%s", _full_path, _dirent.name);
                ScanItem(dirpathnested, _dirent.name, dirnode);
                if (CheckPauseOrStop())
                    return false;
                return true;
            });
            if(iter_ret != VFSError::Ok)
            {
                int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(stat_ret) ForFile:fullpath.c_str()]
                              WaitForResult];
                if (result == OperationDialogResult::Retry) goto retry_opendir;
                else if (result == OperationDialogResult::SkipAll) m_SkipAll = true;
                else if (result == OperationDialogResult::Stop)
                {
                    RequestStop();
                    return;
                }
            }
        }
        // else...
    }
    // else...
}

void FileCopyOperationJobGenericToGeneric::ProcessItems()
{
    m_Stats.StartTimeTracking();
    
    int n = 0;
    for(const auto&i: m_ScannedItems)
    {
        m_CurrentlyProcessingItem = &i;
        
        ProcessItem(m_CurrentlyProcessingItem, n++);
        
        if(CheckPauseOrStop()) return;
    }
    
    m_Stats.SetCurrentItem(nullptr);
}

void FileCopyOperationJobGenericToGeneric::ProcessItem(const chained_strings::node *_node, int _number)
{
    // compose real src name
    string itemname = _node->to_str_with_pref();
    path sourcepath = m_SrcDir / itemname;
    path destinationpath = m_Destination / itemname;

    if(sourcepath == destinationpath)
        return;
    

    if(m_ItemFlags[_number] & (int)ItemFlags::is_dir)
    {
//        assert(itemname[strlen(itemname)-1] == '/');
        CopyDirectoryTo(sourcepath, destinationpath);
    }
    else
    {
        CopyFileTo(sourcepath, destinationpath);
    }
}

void FileCopyOperationJobGenericToGeneric::CopyFileTo(const path &_src_full_path, const path &_dest_full_path)
{
    int ret;
    uint64_t total_wrote = 0;
    
    VFSFilePtr src_file, dst_file;
    VFSStat src_stat, dst_stat;

    
statsource:
    ret = m_SrcHost->Stat(_src_full_path.c_str(), src_stat, 0, 0);
    if(ret < 0)
    { // failed to stat source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src_full_path.c_str()] WaitForResult];
        if(result == OperationDialogResult::Retry) goto createsource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
createsource:
    ret = m_SrcHost->CreateFile(_src_full_path.c_str(), src_file, 0);
    if(ret < 0)
    { // failed to create source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src_full_path.c_str()] WaitForResult];
        if(result == OperationDialogResult::Retry) goto createsource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
opensource:
    ret = src_file->Open(VFSFile::OF_Read | VFSFile::OF_ShLock | VFSFile::OF_NoCache);
    if(ret < 0)
    { // failed to open source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src_full_path.c_str()] WaitForResult];
        if(result == OperationDialogResult::Retry) goto opensource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
    ret = m_DstHost->Stat(_dest_full_path.c_str(), dst_stat, 0, 0);
    if(ret == 0)
    {
        // handle this later
        assert(0);

    }

createdest:
    ret = m_DstHost->CreateFile(_dest_full_path.c_str(), dst_file, 0);
    assert(ret == 0); // handle later
    
opendest:
    ret = dst_file->Open(VFSFile::OF_Write | VFSFile::OF_Create | VFSFile::OF_NoCache);
    assert(ret == 0); // handle later
    

    while( total_wrote < src_stat.size )
    {
        ssize_t read_amount = src_file->Read(m_Buffer.get(), BUFFER_SIZE);
        assert(read_amount >= 0); // handle later
        
        
        size_t to_write = read_amount;
        while(to_write > 0)
        {
            ssize_t write_amount = dst_file->Write(m_Buffer.get(), to_write);
            assert(write_amount >= 0); // handle later
            
            to_write -= write_amount;
            total_wrote += write_amount;
            
        }
    }

    dst_file->Close();
    src_file->Close();
    
cleanup:;
    
}

void FileCopyOperationJobGenericToGeneric::CopyDirectoryTo(const path &_src_full_path, const path &_dest_full_path)
{
    m_DstHost->CreateDirectory(_dest_full_path.c_str(), 0);
    
    // TODO: existance checking, attributes, error handling and other stuff

//    mkdir(_dest, 0777);
    
/*    VFSStat src_stat_buffer;
    if(m_SrcHost->Stat(_src, src_stat_buffer, 0, 0) < 0)
        return false;
    
    // change unix mode
    mode_t mode = src_stat_buffer.mode;
    if((mode & (S_IRWXU | S_IRWXG | S_IRWXO)) == 0)
    { // guard against malformed(?) archives
        mode |= S_IRWXU | S_IRGRP | S_IXGRP;
    }
    chmod(_dest, mode);
    
    // change flags
    chflags(_dest, src_stat_buffer.flags);
    
    // xattr processing
    if(m_Options.copy_xattrs)
    {
        shared_ptr<VFSFile> src_file;
        if(m_SrcHost->CreateFile(_src, src_file, 0) >= 0)
            if(src_file->Open(VFSFile::OF_Read || VFSFile::OF_ShLock) >= 0)
                if(src_file->XAttrCount() > 0)
                    CopyXattrsFn(src_file, _dest);
    }
    
    return true;*/
}
