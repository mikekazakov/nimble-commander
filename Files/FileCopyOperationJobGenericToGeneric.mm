//
//  FileCopyOperationJobGenericToGeneric.cpp
//  Files
//
//  Created by Michael G. Kazakov on 24.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "FileCopyOperationJobGenericToGeneric.h"

static const size_t BUFFER_SIZE = (512*1024); // 512kb

FileCopyOperationJobGenericToGeneric::FileCopyOperationJobGenericToGeneric():
    m_Buffer(new uint8_t[BUFFER_SIZE])
{
}

FileCopyOperationJobGenericToGeneric::~FileCopyOperationJobGenericToGeneric()
{
}

void FileCopyOperationJobGenericToGeneric::Init(chained_strings _src_files,
                                                const char *_src_root,               // dir in where files are located
                                                shared_ptr<VFSHost> _src_host,       // src host to deal with
                                                const char *_dest,                   // where to copy
                                                shared_ptr<VFSHost> _dst_host,       // dst host to deal with
                                                FileCopyOperationOptions* _opts,
                                                FileCopyOperation *_op
                                                )
{
    assert(_src_host);
    assert(_dst_host);
    assert(_src_root && _src_root[0] == '/');
    assert(_dest && _dest[0] != 0);
    m_Operation = _op;
    m_InitialItems = move(_src_files);
    m_Options = *_opts;
    m_SrcHost = _src_host;
    m_SrcDir = _src_root;
    if(m_SrcDir.back() != '/') m_SrcDir += '/';
    
    m_Destination =  _dest;
    m_DstHost = _dst_host;
}

void FileCopyOperationJobGenericToGeneric::Do()
{
    sleep(1);
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
//    char fullpath[MAXPATHLEN];
//    strcpy(fullpath, m_SrcDir);
//    strcat(fullpath, _full_path);
    string fullpath = m_SrcDir + _full_path;
    
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
    string sourcepath = m_SrcDir + itemname;
    string destinationpath = m_Destination + itemname;

    if(sourcepath == destinationpath)
        return;
    

    if(m_ItemFlags[_number] & (int)ItemFlags::is_dir)
    {
//        assert(itemname[strlen(itemname)-1] == '/');
//        CopyDirectoryTo(sourcepath, destinationpath);
    }
    else
    {
        CopyFileTo(sourcepath, destinationpath);
    }
}

void FileCopyOperationJobGenericToGeneric::CopyFileTo(const string &_src, const string &_dest)
{
    int ret;
    uint64_t total_wrote = 0;
    
    VFSFilePtr src_file, dst_file;
    VFSStat src_stat, dst_stat;

    
statsource:
    ret = m_SrcHost->Stat(_src.c_str(), src_stat, 0, 0);
    if(ret < 0)
    { // failed to stat source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src.c_str()] WaitForResult];
        if(result == OperationDialogResult::Retry) goto createsource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
createsource:
    ret = m_SrcHost->CreateFile(_src.c_str(), src_file, 0);
    if(ret < 0)
    { // failed to create source file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src.c_str()] WaitForResult];
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
        int result = [[m_Operation OnCopyCantAccessSrcFile:VFSError::ToNSError(ret) ForFile:_src.c_str()] WaitForResult];
        if(result == OperationDialogResult::Retry) goto opensource;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
    ret = m_DstHost->Stat(_dest.c_str(), dst_stat, 0, 0);
    if(ret == 0)
    {
        // handle this later
        assert(0);

    }

createdest:
    ret = m_DstHost->CreateFile(_dest.c_str(), dst_file, 0);
    assert(ret == 0); // handle later
    
opendest:
    ret = dst_file->Open(VFSFile::OF_Write | VFSFile::OF_Create | VFSFile::OF_NoCache);
    assert(ret == 0); // handle later
    

    while( total_wrote < src_stat.size )
    {
        ssize_t read_amount = src_file->Read(m_Buffer.get(), BUFFER_SIZE);
        assert(read_amount >= 0);
        
        
        size_t to_write = read_amount;
        while(to_write > 0)
        {
            ssize_t write_amount = dst_file->Write(m_Buffer.get(), to_write);
            assert(write_amount >= 0);
            
            to_write -= write_amount;
            total_wrote += write_amount;
            
        }
    }
    
    
    /*
    while ( (res_read = _src->Read(buf, min(bufsz, left_read))) > 0 )
    {
        ssize_t res_write = 0;
        while(res_read > 0)
        {
            res_write = _dst->Write(buf, res_read);
            if(res_write >= 0)
            {
                res_read -= res_write;
                total_wrote += res_write;
            }
            else
                return (int)res_write;
        }
    }
    */
    dst_file->Close();
    src_file->Close();
    
cleanup:;
    
}
