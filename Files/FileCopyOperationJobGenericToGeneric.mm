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
    assert(_dst_host->IsNativeFS() == false);
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
//    sleep(1); // what for????
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

void FileCopyOperationJobGenericToGeneric::ScanItem(const string &_full_path, const string &_short_path, const chained_strings::node *_prefix)
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
            m_SourceNumberOfFiles++;
            m_SourceTotalBytes += stat_buffer.size;
        }
        else if(S_ISDIR(stat_buffer.mode))
        {
            m_ItemFlags.push_back((uint8_t)ItemFlags::is_dir);
            m_ScannedItems.push_back(string(_short_path) + '/', _prefix);
            m_SourceNumberOfDirectories++;
            auto dirnode = &m_ScannedItems.back();
            
        retry_opendir:
            int iter_ret = m_SrcHost->IterateDirectoryListing(fullpath.c_str(), ^bool(const VFSDirEnt &_dirent){
                ScanItem(string(_full_path) + '/' + _dirent.name, _dirent.name, dirnode);
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
    path entryname = _node->to_str_with_pref();
    path sourcepath = m_SrcDir / entryname;
    path destinationpath = m_Destination / entryname;

    if(sourcepath == destinationpath)
        return;
    

    if(m_ItemFlags[_number] & (int)ItemFlags::is_dir)
    {
//        assert(itemname[strlen(itemname)-1] == '/');
        CopyDirectoryTo(sourcepath, destinationpath);
    }
    else
    {
//        NSLog(@">>>>>>>>>>>>>>> Copying File %s <<<<<<<<<<<<<<<<<<", destinationpath.c_str());
        CopyFileTo(sourcepath, destinationpath);
    }
}

void FileCopyOperationJobGenericToGeneric::CopyFileTo(const path &_src_full_path, const path &_dest_full_path)
{
    int ret;
    int dstopenflags=0;
    bool remember_choice = false, unlink_on_stop = false, was_successful = false;
    uint64_t total_wrote = 0;
    uint64_t totaldestsize = 0;
    ssize_t startwriteoff = 0;
    
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
    totaldestsize = src_stat.size;
    
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
    if(ret == 0) { //file already exist - what should we do?
        int result;
        if(m_SkipAll) goto cleanup;
        if(m_OverwriteAll) goto dec_overwrite;
        if(m_AppendAll) goto dec_append;
        
        result = [[m_Operation OnFileExist:_dest_full_path.c_str()
                                   newsize:src_stat.size
                                   newtime:src_stat.mtime.tv_sec
                                   exisize:dst_stat.size
                                   exitime:dst_stat.mtime.tv_sec
                                  remember:&remember_choice] WaitForResult];
        if(result == FileCopyOperationDR::Overwrite){ if(remember_choice) m_OverwriteAll = true;  goto dec_overwrite; }
        if(result == FileCopyOperationDR::Append)   { if(remember_choice) m_AppendAll = true;     goto dec_append;    }
        if(result == OperationDialogResult::Skip)   { if(remember_choice) m_SkipAll = true;       goto cleanup;      }
        if(result == OperationDialogResult::Stop)   { RequestStop(); goto cleanup; }
        
        // decisions about what to do with existing destination
    dec_overwrite:
        dstopenflags = VFSFile::OF_Write | VFSFile::OF_Truncate | VFSFile::OF_NoCache;
        unlink_on_stop = true;
        goto dec_end;
    dec_append:
        dstopenflags = VFSFile::OF_Write | VFSFile::OF_Append | VFSFile::OF_NoCache;
        totaldestsize += dst_stat.size;
        startwriteoff = dst_stat.size;
        unlink_on_stop = false;
    dec_end:;
    } else {
        // no dest file - just create it
        dstopenflags = VFSFile::OF_Write | VFSFile::OF_Create | VFSFile::OF_NoCache;
        unlink_on_stop = true;
    }

createdest:
    ret = m_DstHost->CreateFile(_dest_full_path.c_str(), dst_file, 0);
    assert(ret == 0); // handle later
    
opendest:
    ret = dst_file->Open(dstopenflags);
    if(ret < 0)
    {   // failed to open destination file
        if(m_SkipAll) goto cleanup;
        int result = [[m_Operation OnCopyCantOpenDestFile:VFSError::ToNSError(ret) ForFile:_dest_full_path.c_str()] WaitForResult];
        if(result == OperationDialogResult::Retry) goto opendest;
        if(result == OperationDialogResult::Skip) goto cleanup;
        if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto cleanup;}
        if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
    }
    
    if(dst_file->Pos() != startwriteoff)
    { // need to seek to the end. (seek pos wasnt set upon opening with )
        auto ret = dst_file->Seek(startwriteoff, VFSFile::Seek_Set);
        assert(ret >= 0);
    }
    
    while( total_wrote < src_stat.size )
    {
        if(CheckPauseOrStop()) goto cleanup;
        
        doread: ssize_t read_amount = src_file->Read(m_Buffer.get(), BUFFER_SIZE);
        if(read_amount < 0)
        {
            if(m_SkipAll) goto cleanup;
            int result = [[m_Operation OnCopyReadError:VFSError::ToNSError((int)read_amount) ForFile:_dest_full_path.c_str()] WaitForResult];
            if(result == OperationDialogResult::Retry) goto doread;
            if(result == OperationDialogResult::Skip) goto cleanup;
            if(result == OperationDialogResult::SkipAll) { m_SkipAll = true; goto cleanup; }
            if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
        }

        size_t to_write = read_amount;
        while(to_write > 0)
        {
            dowrite: ssize_t write_amount = dst_file->Write(m_Buffer.get(), to_write);
            if(write_amount < 0)
            {
                if(m_SkipAll) goto cleanup;
                int result = [[m_Operation OnCopyWriteError:VFSError::ToNSError((int)write_amount) ForFile:_dest_full_path.c_str()] WaitForResult];
                if(result == OperationDialogResult::Retry) goto dowrite;
                if(result == OperationDialogResult::Skip) goto cleanup;
                if(result == OperationDialogResult::SkipAll) { m_SkipAll = true; goto cleanup; }
                if(result == OperationDialogResult::Stop) { RequestStop(); goto cleanup; }
            }
            
            to_write -= write_amount;
            total_wrote += write_amount;
        }
    }

    was_successful = true;
    
cleanup:;
    src_file->Close();
    src_file.reset();
    dst_file->Close();
    dst_file.reset();
    
    if(was_successful == false &&
       unlink_on_stop == true)
        m_DstHost->Unlink(_dest_full_path.c_str(), 0);
}

void FileCopyOperationJobGenericToGeneric::CopyDirectoryTo(const path &_src_full_path, const path &_dest_full_path)
{
    int ret = m_DstHost->CreateDirectory(_dest_full_path.c_str(), 0);
    assert(ret == 0); // handle me later
    
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
