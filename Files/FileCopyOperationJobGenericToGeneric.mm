//
//  FileCopyOperationJobGenericToGeneric.cpp
//  Files
//
//  Created by Michael G. Kazakov on 24.03.14.
//  Copyright (c) 2014 Michael G. Kazakov. All rights reserved.
//

#include "FileCopyOperationJobGenericToGeneric.h"
#include "Common.h"

FileCopyOperationJobGenericToGeneric::FileCopyOperationJobGenericToGeneric()
{
}

FileCopyOperationJobGenericToGeneric::~FileCopyOperationJobGenericToGeneric()
{
}

void FileCopyOperationJobGenericToGeneric::Init(vector<string> _src_files,
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
//    if(!IsRunningUnitTesting())
        // fo general usage this should not be used with native fs - there's a direct variant, without VFS layering
//        assert(_dst_host->IsNativeFS() == false);
    assert(_src_root.is_absolute());
    m_Operation = _op;
    m_InitialItems = move(_src_files);
    m_Options = _opts;
    m_SrcHost = _src_host;
    m_SrcDir = _src_root;
    
    /*m_Destination = */ m_OriginalDestination = _dest;
//    m_DstHost = _dst_host;
    
    m_OrigSrcHost = _src_host;
    m_OrigDstHost = _dst_host;
    
    if(m_Options.force_overwrite)
        m_OverwriteAll = true;    
}

void FileCopyOperationJobGenericToGeneric::Do()
{
    Analyze();
    if(CheckPauseOrStop()) { SetStopped(); return; }

    // check that Analyze() done what it should.
    assert(m_Destination.empty() == false);
    assert(m_DstHost != nullptr);
    
    if(m_WorkMode == WorkMode::CopyToPathName    ||
       m_WorkMode == WorkMode::CopyToPathPreffix ||
       m_WorkMode == WorkMode::MoveToPathPreffix  )
    {
        ScanItems();
    }
    else
    {
        // no need for deep scanning
        for(auto &i:m_InitialItems)
            m_ScannedItems.push_back(i, nullptr);
    }
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    m_Stats.SetMaxValue(m_SourceTotalBytes);
    
    ProcessItems();
    if(CheckPauseOrStop()) { SetStopped(); return; }
    
    SetCompleted();
}

void FileCopyOperationJobGenericToGeneric::Analyze()
{
    VFSStat st;
    m_IsSingleEntryCopy = m_InitialItems.size() == 1;

    // currently assuming that this is a copying, not moving
    
    // lets analyze what user wants from us.
    if(m_OriginalDestination.is_absolute() == true)
    {
        // seems to be fairly easy - just use this dest as a preffix or as a path name
        
        if(m_OriginalDestination.filename() != "." &&
           m_IsSingleEntryCopy &&
           m_OrigSrcHost->Stat((m_SrcDir / m_InitialItems.front().c_str()).c_str(), st, 0, 0) == 0 &&
           st.mode_bits.reg ) {
            m_WorkMode = m_Options.docopy ? WorkMode::CopyToPathName : WorkMode::RenameToPathName;
            m_Destination = m_OriginalDestination;
            m_DstHost = m_OrigDstHost;
        }
        else {
            m_Destination = m_OriginalDestination;
            m_DstHost = m_OrigDstHost;
            if(m_Options.docopy)
                m_WorkMode = WorkMode::CopyToPathPreffix;
            else
            {
                if(m_SrcHost == m_OrigDstHost)
                    m_WorkMode = WorkMode::RenameToPathPreffix;
                else
                    m_WorkMode = WorkMode::MoveToPathPreffix;
            }
            
            // now we need to check if this path is valid and available
            if(m_DstHost->Stat(m_Destination.c_str(), st, 0, 0) != 0)
                BuildDirectories(m_Destination, m_DstHost);
        }
    }
    else
    {
        // relative path: result_path = files_path / requested_path
        if(m_OriginalDestination.filename() == "." || // check for trailing slash
           m_IsSingleEntryCopy == false )
        {
            // user wants to put files into a dir m_OriginalDestination that is in m_SrcDir
            // we work at the same host as where original files are, no need for m_OrigDstHost
            m_WorkMode = m_Options.docopy ? WorkMode::CopyToPathPreffix : WorkMode::RenameToPathPreffix;
            m_Destination = m_SrcDir / m_OriginalDestination;
            m_DstHost = m_SrcHost;
            m_OrigDstHost.reset();
            
            if(m_DstHost->Stat(m_Destination.c_str(), st, 0, 0) != 0)
                BuildDirectories(m_Destination, m_DstHost);
        }
        else
        {
            // user want to put files into a dir m_OriginalDestination that is in m_SrcDir.
            // meanwhile, this is a name for a topmost entries.
            // we work at the same host as where original files are, no need for m_OrigDstHost
            m_WorkMode = m_Options.docopy ? WorkMode::CopyToPathName : WorkMode::RenameToPathName;
            m_Destination = m_SrcDir / m_OriginalDestination;
            m_DstHost = m_SrcHost;
            m_OrigDstHost.reset();
            
            path tmp = m_Destination;
            tmp.remove_filename();
            if(m_DstHost->Stat(tmp.c_str(), st, 0, 0) != 0)
                BuildDirectories(tmp, m_DstHost); // we also build a path (if need) except the last element
        }
        
        
        
    }
}

void FileCopyOperationJobGenericToGeneric::BuildDirectories(const path &_dir, const VFSHostPtr& _host)
{
    vector<path> to_create;
    
    path tmp = _dir;
    if(tmp.filename() == ".") tmp.remove_filename();
    
    while( tmp != "/" )
    {
        VFSStat st;
        if(_host->Stat(tmp.c_str(), st, 0, 0) == 0)
            break;
        to_create.emplace_back(tmp);
        tmp = tmp.parent_path();
    }
    
    for(auto i = rbegin(to_create); i != rend(to_create); ++i)
    {
    mkdir:;
        int ret = _host->CreateDirectory(i->c_str(), 0755, 0);
        if(ret != 0)
        {
            int result = [[m_Operation OnCantCreateDir:VFSError::ToNSError(ret) ForDir:i->c_str()] WaitForResult];
            if (result == OperationDialogResult::Retry) goto mkdir;
            if (result == OperationDialogResult::Stop) { RequestStop(); return; }
        }
    }
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
            int iter_ret = m_SrcHost->IterateDirectoryListing(fullpath.c_str(), [&](const VFSDirEnt &_dirent){
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
    
    m_Stats.SetCurrentItem("");
    
    ProcessFilesRemoval();
    ProcessFoldersRemoval();    
}

void FileCopyOperationJobGenericToGeneric::ProcessItem(const chained_strings::node *_node, int _number)
{
    // compose real src name
    path entryname = _node->to_str_with_pref();
    path sourcepath = m_SrcDir / entryname;
    path destinationpath;
    
    if(m_WorkMode == WorkMode::CopyToPathPreffix   ||
       m_WorkMode == WorkMode::RenameToPathPreffix ||
       m_WorkMode == WorkMode::MoveToPathPreffix    )
        destinationpath = m_Destination / entryname;
    else if(m_WorkMode == WorkMode::CopyToPathName  ||
            m_WorkMode == WorkMode::RenameToPathName )
    {
        destinationpath = m_Destination;
        if(entryname.has_parent_path())
            for(auto i = ++entryname.begin(), e = entryname.end(); i != e;)
                destinationpath /= *i++;
    }

    if(m_SrcHost == m_DstHost && sourcepath == destinationpath)
        return;
    
    if(destinationpath.filename() == ".")
        destinationpath.remove_filename(); // get rid of trailing slashes
    
    if(m_WorkMode == WorkMode::CopyToPathName    ||
       m_WorkMode == WorkMode::CopyToPathPreffix ||
       m_WorkMode == WorkMode::MoveToPathPreffix  )
    {
        bool result = false;
        if(m_ItemFlags[_number] & (int)ItemFlags::is_dir)
        {
            result = CopyDirectoryTo(sourcepath, destinationpath);
            if(result == true && m_WorkMode == WorkMode::MoveToPathPreffix)
                m_DirsToDelete.push_back(_node);
        }
        else
        {
            result = CopyFileTo(sourcepath, destinationpath);
            if(result == true && m_WorkMode == WorkMode::MoveToPathPreffix)
                m_FilesToDelete.push_back(_node);
        }
        
    }
    else if(m_WorkMode == WorkMode::RenameToPathPreffix ||
            m_WorkMode == WorkMode::RenameToPathName )
    {
        RenameEntry(sourcepath, destinationpath);
    }
}

void FileCopyOperationJobGenericToGeneric::ProcessFilesRemoval()
{
    for(auto i: m_FilesToDelete)
    {
        path p = m_SrcDir / i->to_str_with_pref();
        m_SrcHost->Unlink(p.c_str(), 0); // any error handling here?
    }
}

void FileCopyOperationJobGenericToGeneric::ProcessFoldersRemoval()
{
    for(auto i = m_DirsToDelete.rbegin(); i != m_DirsToDelete.rend(); ++i)
    {
        path p = m_SrcDir / (*i)->to_str_with_pref();
        if(p.filename() == ".") p.remove_filename();
        m_SrcHost->RemoveDirectory(p.c_str(), 0); // any error handling here?
    }
}

bool FileCopyOperationJobGenericToGeneric::CopyFileTo(const path &_src_full_path, const path &_dest_full_path)
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
    ret = src_file->Open(VFSFlags::OF_Read | VFSFlags::OF_ShLock | VFSFlags::OF_NoCache);
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
        dstopenflags = VFSFlags::OF_Write | VFSFlags::OF_Truncate | VFSFlags::OF_NoCache;
        unlink_on_stop = true;
        goto dec_end;
    dec_append:
        dstopenflags = VFSFlags::OF_Write | VFSFlags::OF_Append | VFSFlags::OF_NoCache;
        totaldestsize += dst_stat.size;
        startwriteoff = dst_stat.size;
        unlink_on_stop = false;
    dec_end:;
    } else {
        // no dest file - just create it
        dstopenflags = VFSFlags::OF_Write | VFSFlags::OF_Create | VFSFlags::OF_NoCache;
        unlink_on_stop = true;
    }

createdest:
    ret = m_DstHost->CreateFile(_dest_full_path.c_str(), dst_file, 0);
    assert(ret == 0); // handle later
    
opendest:
    if(m_Options.copy_unix_flags) // we want to copy src permissions
        dstopenflags |= src_stat.mode & (S_IRWXU | S_IRWXG | S_IRWXO);
    else // open file with default permissions
        dstopenflags |= S_IRUSR | S_IWUSR | S_IRGRP;
        
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
        
        doread: ssize_t read_amount = src_file->Read(m_Buffer.get(), m_BufferSize);
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
            m_TotalCopied += write_amount;
        }
        
        // update statistics
        m_Stats.SetValue(m_TotalCopied);
    }

    // TODO:
    // xattrs
    // owners
    // flags
    // file times

    was_successful = true;
    
cleanup:;
    src_file.reset();
    dst_file.reset();
    
    if(was_successful == false &&
       unlink_on_stop == true)
        m_DstHost->Unlink(_dest_full_path.c_str(), 0);
    
    return was_successful;
}

bool FileCopyOperationJobGenericToGeneric::CopyDirectoryTo(const path &_src_full_path, const path &_dest_full_path)
{
    bool res = false;
    VFSStat src_st, dest_st;
 
    if(m_SrcHost->Stat(_src_full_path.c_str(), src_st, 0, 0) != 0)
        return false;
    
    
    if(m_DstHost->Stat(_dest_full_path.c_str(), dest_st, VFSFlags::F_NoFollow, 0) == 0)
    {
        // this directory already exist. currently do nothing, later - update it's attrs.
        res = true;
    }
    else
    {
    domkdir:
        int ret = m_DstHost->CreateDirectory(_dest_full_path.c_str(), src_st.mode, 0);
        if(ret < 0)
        {
            if(m_SkipAll) goto end;
            int result = [[m_Operation OnCantCreateDir:VFSError::ToNSError(ret) ForDir:_dest_full_path.c_str()] WaitForResult];
            if(result == OperationDialogResult::Retry) goto domkdir;
            if(result == OperationDialogResult::Skip) goto end;
            if(result == OperationDialogResult::SkipAll) {m_SkipAll = true; goto end;}
            if(result == OperationDialogResult::Stop)  { RequestStop(); goto end; }
        }
        res = true;
    }
    
end:return res;
}

void FileCopyOperationJobGenericToGeneric::RenameEntry(const path &_src_full_path, const path &_dest_full_path)
{
    if( m_SrcHost->Exists(_dest_full_path.c_str()) ) {
        int result = [[m_Operation OnRenameDestinationExists:_dest_full_path.c_str() Source:_src_full_path.c_str()]
                      WaitForResult];
    
        if (result == OperationDialogResult::Stop) { RequestStop(); return; }
    }
    
retry_rename:
    int ret = m_SrcHost->Rename(_src_full_path.c_str(), _dest_full_path.c_str(), 0);
    if (ret != 0) {
        int result = [[m_Operation OnCopyWriteError:VFSError::ToNSError(ret) ForFile:_dest_full_path.c_str()] WaitForResult];
        if (result == OperationDialogResult::Retry) goto retry_rename;
        else if (result == OperationDialogResult::Stop) { RequestStop(); return; }
    }
}
